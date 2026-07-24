import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';
import '../core/debug/debug_config.dart';
import '../core/notifications/fcm_service.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/encryption_utils.dart';
import '../shared/utils/mention_utils.dart';
import '../features/chat/utils/system_message_formatter.dart';
import 'group_search_repository.dart';
import 'package:collection/collection.dart';

part 'group_chat_mixin.dart';
part 'chat_repository_delete.dart';
part 'chat_repository_clear.dart';
part 'chat_repository_message_actions.dart';

class ChatRepositoryImpl with GroupChatMixin, ChatDeleteMixin, ChatClearMixin, ChatMessageActionsMixin implements ChatRepository {
  @override
  final FirebaseFirestore firestore;
  @override
  final FirebaseAuth auth;
  @override
  final AppDatabase db;

  // Cache αποκρυπτογραφημένων messages — αποφυγή re-decrypt σε κάθε Firestore snapshot
  final Map<String, Map<String, String>> _messageEncryptCache = {};
  final Map<String, Map<String, String>> _messageDecryptCache = {};
  final Map<String, List<Map<String, dynamic>>> _lastMessagesListCache = {};

  @override
  Map<String, Map<String, String>> get messageEncryptCache => _messageEncryptCache;
  @override
  Map<String, Map<String, String>> get messageDecryptCache => _messageDecryptCache;

  @override
  void clearMessageCaches(String chatId) {
    _messageEncryptCache.remove(chatId);
    _messageDecryptCache.remove(chatId);
    _lastMessagesListCache.remove(chatId);
    DebugConfig.log(DebugConfig.providerDispose, 'clearMessageCaches: cleared caches for chat=$chatId');
  }

  ChatRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AppDatabase? db,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        db = db ?? DatabaseService.instance;

  @override
  Future<String> createChat(String otherUid) async {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('create_chat', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'createChat: blocked unverified user');
      throw AppException.auth('create_chat', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να ξεκινήσεις συνομιλία / You must verify your account');
    }

    final uid = user.uid;

    try {
      final blockedDoc = await firestore
          .collection('users').doc(otherUid).collection('blocked').doc(uid)
          .get();
      if (blockedDoc.exists) {
        DebugConfig.log(DebugConfig.repositoryCall, 'createChat: blocked by $otherUid');
        throw AppException.auth('create_chat',
            'Δεν μπορείς να ξεκινήσεις συνομιλία με αυτόν τον χρήστη / You cannot start a chat with this user');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.warn('createChat: block check failed (non-fatal)', data: e);
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'createChat: $uid with $otherUid');

    final existing = await _findExistingChat(uid, otherUid);
    if (existing != null) {
      DebugConfig.log(DebugConfig.repositoryResult, 'createChat: existing chat found: $existing');
      return existing;
    }

    DebugConfig.log(DebugConfig.repositoryCall,
        'createChat: fetching profiles in parallel uid=$uid with=$otherUid');
    final results = await Future.wait([
      firestore.collection('users').doc(uid).collection('public').doc('profile').get(),
      firestore.collection('users').doc(otherUid).collection('public').doc('profile').get(),
    ]);
    final myProfile = results[0];
    final myNickname = myProfile.data()?['nickname'] as String? ?? uid;
    final myAvatarUrl = myProfile.data()?['avatarUrl'] as String?;
    final otherProfile = results[1];
    final otherNickname = otherProfile.data()?['nickname'] as String? ?? otherUid;
    final otherAvatarUrl = otherProfile.data()?['avatarUrl'] as String?;
    DebugConfig.log(DebugConfig.repositoryResult,
        'createChat: myNickname=$myNickname '
        'otherUid=$otherUid otherProfileExists=${otherProfile.exists} '
        'otherDocHasNickname=${otherProfile.data()?.containsKey('nickname')} '
        'otherNickname=$otherNickname '
        'hasMyAvatar=${myAvatarUrl != null} hasOtherAvatar=${otherAvatarUrl != null}');

    final chatId = firestore.collection('chats').doc().id;
    final sortedPair = [uid, otherUid]..sort();
    final pairKey = '${sortedPair[0]}_${sortedPair[1]}';
    final key = EncryptionUtils.deriveKey(chatId);
    await firestore.collection('chats').doc(chatId).set({
      'participants': [uid, otherUid],
      'participantPair': pairKey,
      'isGroupChat': false,
      'participantNicknames': {uid: myNickname, otherUid: otherNickname},
      'participantAvatarUrls': {
        uid: ?myAvatarUrl,
        otherUid: ?otherAvatarUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'maxParticipants': 2,
      'unreadCount': {uid: 0, otherUid: 0},
    });
    DebugConfig.log(DebugConfig.repositoryResult, 'createChat: new chat created: $chatId pair=$pairKey');
    DebugConfig.log(DebugConfig.repositoryResult, 'createChat: new chat created: $chatId');

    await EncryptionUtils.storeKey(chatId, key);
    // Chat cache γίνεται από το Firestore listener (streamChats → _syncChatFromFirestore)
    await logConsent(uid, otherUid);

    return chatId;
  }

  Future<String?> _findExistingChat(String uid1, String uid2) async {
    try {
      final pairKey = [uid1, uid2]..sort();
      final pairStr = '${pairKey[0]}_${pairKey[1]}';

      // Tier 2 — participantPair direct hit
      DebugConfig.log(DebugConfig.repositoryCall,
          '_findExistingChat: Tier 2 lookup pair=$pairStr');
      final pairSnapshot = await firestore
          .collection('chats')
          .where('participantPair', isEqualTo: pairStr)
          .where('isGroupChat', isEqualTo: false)
          .limit(1)
          .get();

      if (pairSnapshot.docs.isNotEmpty) {
        final doc = pairSnapshot.docs.first;
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(uid1) && participants.contains(uid2)) {
          DebugConfig.log(DebugConfig.repositoryResult,
              '_findExistingChat: Tier 2 hit chat=${doc.id}');
          return doc.id;
        }
        DebugConfig.log(DebugConfig.repositoryResult,
            '_findExistingChat: Tier 2 hit but inactive, fall through');
      }

      // Tier 3 — legacy fallback (old chats without participantPair)
      DebugConfig.log(DebugConfig.repositoryCall,
          '_findExistingChat: Tier 3 legacy fallback uid1=$uid1');
      final legacySnapshot = await firestore
          .collection('chats')
          .where('participants', arrayContains: uid1)
          .limit(10)
          .get();

      for (final doc in legacySnapshot.docs) {
        final data = doc.data();
        if (data['isGroupChat'] == true) {
          DebugConfig.log(DebugConfig.repositoryResult,
              '_findExistingChat: skip group chat=${doc.id} for 1-on-1 lookup');
          continue;
        }
        final participants = List<String>.from(data['participants'] ?? []);
        if (!participants.contains(uid2)) continue;
        if (participants.length != 2) {
          DebugConfig.log(DebugConfig.repositoryResult,
              '_findExistingChat: skip multi-participant chat=${doc.id} (${participants.length} members)');
          continue;
        }

        // Self-healing lazy backfill
        await firestore.collection('chats').doc(doc.id).update({
          'participantPair': pairStr,
          'isGroupChat': false,
        }).catchError((_) {});
        DebugConfig.log(DebugConfig.repositoryResult,
            '_findExistingChat: Tier 3 hit + backfill chat=${doc.id}');
        return doc.id;
      }
    } catch (e) {
      DebugConfig.warn('_findExistingChat failed', data: e);
    }
    return null;
  }

  @override
  Future<void> sendMessage(String chatId, String content, {Map<String, dynamic>? replyTo}) async {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('send_message', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'sendMessage: blocked unverified user');
      throw AppException.auth('send_message', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να στείλεις μήνυμα / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'sendMessage: chat=$chatId');

    List<String>? validMentions;
    List<String> participants = [];
    bool isGroupChat = false;
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw AppException.firestore('send_message', 'Η συνομιλία δεν βρέθηκε / Chat not found');
      }
      final data = chatDoc.data()!;
      participants = List<String>.from(data['participants'] ?? []);
      isGroupChat = data['isGroupChat'] == true;

      if (isGroupChat) {
        final nicknames = Map<String, String>.from(data['participantNicknames'] ?? {});
        final uids = MentionService.extractMentions(content, nicknames);
        validMentions = MentionService.validateParticipants(uids, participants);
        if (validMentions.isNotEmpty) {
          DebugConfig.log(DebugConfig.repositoryCall,
              'sendMessage: extracted ${validMentions.length} mentions chat=$chatId');
        }
      }

      if (!isGroupChat) {
        final otherUid = participants.where((p) => p != user.uid).firstOrNull;
        if (otherUid != null) {
          final blockedDoc = await firestore
              .collection('users').doc(otherUid).collection('blocked').doc(user.uid)
              .get();
          if (blockedDoc.exists) {
            DebugConfig.log(DebugConfig.repositoryCall, 'sendMessage: blocked by $otherUid');
            throw AppException.auth('send_message',
                'Δεν μπορείς να στείλεις μήνυμα σε αυτόν τον χρήστη / You cannot send messages to this user');
          }
        }
      }
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.warn('sendMessage: block check failed (non-fatal)', data: e);
    }

    final key = await EncryptionUtils.getKeyOrDerive(chatId);

    try {
      final encrypted = EncryptionUtils.encryptMessage(key, content);

      final msgRef = firestore
          .collection('chats').doc(chatId).collection('messages').doc();
      final chatRef = firestore.collection('chats').doc(chatId);
      final batch = firestore.batch();

      final msgData = <String, dynamic>{
        'senderId': user.uid,
        'content': encrypted,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      if (validMentions != null && validMentions.isNotEmpty) {
        msgData['mentions'] = validMentions;
      }
      if (replyTo != null) {
        msgData['replyTo'] = replyTo;
      }
      batch.set(msgRef, msgData);
      final updateData = <String, dynamic>{
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': user.uid,
        'lastMessage': encrypted,
        'lastMessageType': 'text',
      };
      for (final p in participants) {
        if (p != user.uid) {
          updateData['unreadCount.$p'] = FieldValue.increment(1);
        }
      }
      batch.update(chatRef, updateData);
      await batch.commit();

      DebugConfig.log(DebugConfig.repositoryResult, 'sendMessage: success chat=$chatId');

      await updateChatCache(chatId, hasUnread: false);
    } catch (e) {
      DebugConfig.error('sendMessage failed', data: e);
      throw AppException.firestore('send_message', 'Αποτυχία αποστολής μηνύματος / Failed to send message');
    }
  }

  @override
  Future<List<ChatCacheTableData>> getChats() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      DebugConfig.warn('getChats: no authenticated user');
      return [];
    }
    DebugConfig.log(DebugConfig.repositoryCall, 'getChats: uid=$uid');
    try {
      final chats = await (db.select(db.chatCacheTable)
        ..where((t) => t.ownerUid.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)])
      ).get();
      DebugConfig.log(DebugConfig.repositoryResult, 'getChats: ${chats.length} chats');
      return chats;
    } catch (e) {
      DebugConfig.error('getChats failed', data: e);
      throw AppException.database('get_chats', e);
    }
  }

  // Αποκρυπτογραφεί ένα μήνυμα-doc (κοινή λογική για messagesStream + fetchOlderMessages).
  // ΙΔΙΑ συμπεριφορά με πριν — μόνο εξήχθη σε helper για επαναχρησιμοποίηση.
  Map<String, dynamic> _decodeMessageDoc(
    String chatId,
    String docId,
    Map<String, dynamic> data,
    encrypt.Key key,
    Map<String, String> encCache,
    Map<String, String> decCache,
  ) {
    final encrypted = data['content'] as String? ?? '';
    final type = data['type'] as String? ?? 'text';

    String decrypted;
    if (type == 'system') {
      decrypted = encrypted;
    } else if (type == 'gif' || type == 'image' || type == 'video' || type == 'audio') {
      decrypted = encrypted;
    } else if (encCache[docId] == encrypted && decCache.containsKey(docId)) {
      decrypted = decCache[docId]!;
    } else {
      try {
        decrypted = EncryptionUtils.decryptMessage(key, encrypted);
        encCache[docId] = encrypted;
        decCache[docId] = decrypted;
      } catch (e) {
        encCache.remove(docId);
        decCache.remove(docId);
        try {
          final fallbackKey = EncryptionUtils.deriveKey(chatId);
          decrypted = EncryptionUtils.decryptMessage(fallbackKey, encrypted);
          encCache[docId] = encrypted;
          decCache[docId] = decrypted;
        } catch (_) {
          DebugConfig.warn('_decodeMessageDoc: decrypt failed for msg $docId', data: e);
          decrypted = '[Μη αναγνώσιμο μήνυμα / Unreadable message]';
        }
      }
    }
    return {
      'id': docId,
      'senderId': data['senderId'] ?? '',
      'content': decrypted,
      'type': data['type'] ?? 'text',
      'timestamp': data['timestamp'],
      'isRead': data['isRead'] ?? false,
      'edited': data['edited'] ?? false,
      'editedAt': data['editedAt'],
      'seenBy': (data['seenBy'] as List?)?.cast<String>() ?? <String>[],
      'mentions': (data['mentions'] as List?)?.cast<String>() ?? <String>[],
      'action': data['action'] as String?,
      'contentEn': data['contentEn'] as String?,
      'reactions': (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      'replyTo': data['replyTo'] as Map<String, dynamic>?,
      'duration': data['duration'] as int? ?? 0,
    };
  }

  static const int _kLiveMessageWindow = 50;

  @override
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) {
    DebugConfig.log(DebugConfig.chatStream,
        'messagesStream: starting listener chat=$chatId (limitToLast=$_kLiveMessageWindow)');

    // ΚΡΙΣΙΜΟ FIX: πριν διάβαζε ΟΛΟ το subcollection messages σε κάθε άνοιγμα
    // chat (unbounded read, κόστος ανάλογο του ιστορικού). Τώρα ο real-time
    // listener κρατάει μόνο τα τελευταία _kLiveMessageWindow μηνύματα.
    // Τα παλιότερα φορτώνονται on-demand μέσω fetchOlderMessages().
    final stream = firestore
        .collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(_kLiveMessageWindow)
        .snapshots()
        .map((snapshot) {
      DebugConfig.log(DebugConfig.chatStream,
          'messagesStream snapshot: ${snapshot.docs.length} docs chat=$chatId');
      return snapshot;
    })
        .asyncMap((snapshot) async {
      DebugConfig.log(DebugConfig.chatStream, 'messagesStream: processing ${snapshot.docs.length} docs for chat=$chatId');
      final key = await EncryptionUtils.getKeyOrDerive(chatId);
      final encCache = _messageEncryptCache.putIfAbsent(chatId, () => {});
      final decCache = _messageDecryptCache.putIfAbsent(chatId, () => {});
      final messages = snapshot.docs
          .map((doc) => _decodeMessageDoc(chatId, doc.id, doc.data(), key, encCache, decCache))
          .toList();

      final msgsWithReactions = messages.where((m) => (m['reactions'] as Map<String, dynamic>?)?.isNotEmpty ?? false).length;
      DebugConfig.log(DebugConfig.chatStream,
          'messagesStream: $msgsWithReactions/${messages.length} msgs have reactions for chat=$chatId');

      // --- ΝΕΟ: equality-caching, ίδιο pattern με chatDocProvider/participantUidsProvider ---
      final previous = _lastMessagesListCache[chatId];
      if (previous != null &&
          const DeepCollectionEquality().equals(previous, messages)) {
        DebugConfig.log(DebugConfig.chatStream,
            'messagesStream: suppressed (content unchanged) chat=$chatId docs=${messages.length}');
        return previous;
      }
      _lastMessagesListCache[chatId] = messages;
      return messages;
      // --- ΤΕΛΟΣ ΝΕΟΥ ΚΩΔΙΚΑ ---
    });

    DebugConfig.log(DebugConfig.chatStream, 'messagesStream: listener active chat=$chatId');
    return stream;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOlderMessages(
    String chatId, {
    required DateTime beforeTimestamp,
    int limit = 50,
  }) async {
    DebugConfig.log(DebugConfig.chatStream,
        'fetchOlderMessages: chat=$chatId before=$beforeTimestamp limit=$limit');
    try {
      final key = await EncryptionUtils.getKeyOrDerive(chatId);
      final encCache = _messageEncryptCache.putIfAbsent(chatId, () => {});
      final decCache = _messageDecryptCache.putIfAbsent(chatId, () => {});

      // One-shot read (όχι listener) — δε δημιουργεί συνεχές κόστος.
      final snapshot = await firestore
          .collection('chats').doc(chatId).collection('messages')
          .orderBy('timestamp', descending: false)
          .endBefore([Timestamp.fromDate(beforeTimestamp)])
          .limitToLast(limit)
          .get();

      final messages = snapshot.docs
          .map((doc) => _decodeMessageDoc(chatId, doc.id, doc.data(), key, encCache, decCache))
          .toList();

      DebugConfig.log(DebugConfig.chatStream,
          'fetchOlderMessages: loaded ${messages.length} older msgs chat=$chatId');
      return messages;
    } catch (e, s) {
      DebugConfig.error('fetchOlderMessages failed', data: e, exception: s);
      throw AppException.database('fetch_older_messages', e);
    }
  }

  @override
  Future<void> markAsRead(String chatId, {bool isGroupChat = false}) async {
    final user = auth.currentUser;
    if (user == null) return;

    DebugConfig.log(DebugConfig.repositoryCall, 'markAsRead: chat=$chatId isGroup=$isGroupChat');

    try {
      // Διαβάζουμε το τοπικό (ήδη συγχρονισμένο) unreadCount ΠΡΙΝ γράψουμε,
      // ώστε να μη γράφουμε serverTimestamp() όταν δεν υπάρχει πραγματικά
      // τίποτα καινούριο να διαβαστεί — αυτό το serverTimestamp είναι που
      // προκαλούσε το rebuild storm σε ομαδικές συνομιλίες.
      final cachedRow = await (db.select(db.chatCacheTable)
        ..where((t) => t.chatId.equals(chatId)))
          .getSingleOrNull();
      final hadUnread = cachedRow == null || cachedRow.unreadCount > 0;

      if (hadUnread) {
        await firestore.collection('chats').doc(chatId).update({
          'lastReadTimestamps.${user.uid}': FieldValue.serverTimestamp(),
          'unreadCount.${user.uid}': 0,
        });
      } else {
        DebugConfig.log(DebugConfig.repositoryCall,
            'markAsRead: skipped lastReadTimestamps write (already 0 unread) chat=$chatId');
      }

      if (!isGroupChat) {
        final unread = await firestore
            .collection('chats').doc(chatId).collection('messages')
            .where('isRead', isEqualTo: false)
            .limit(50)
            .get();

        final docs = unread.docs.where((d) => d.data()['senderId'] != user.uid).toList();

        if (docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
          DebugConfig.log(DebugConfig.repositoryResult, 'markAsRead: marked ${docs.length} messages chat=$chatId');
        } else {
          DebugConfig.log(DebugConfig.repositoryResult, 'markAsRead: no unread messages chat=$chatId');
        }
      }

      await (db.update(db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
          .write(const ChatCacheTableCompanion(hasUnread: Value(false), unreadCount: Value(0)));
      DebugConfig.log(DebugConfig.databaseLocal, 'markAsRead: cache updated chat=$chatId');
    } catch (e) {
      DebugConfig.error('markAsRead failed', data: e);
      throw AppException.firestore('mark_read', 'Αποτυχία ενημέρωσης / Failed to mark as read');
    }
  }

  @override
  Future<void> updateChatCache(String chatId, {DateTime? lastMessageAt, bool? hasUnread, String? otherNickname, String? otherAvatarUrl, String? lastMessage, String? lastMessageSender, String? lastMessageType, int? unreadCount, String? groupName, String? groupAvatarUrl}) async {
    try {
      var rows = await (db.select(db.chatCacheTable)
        ..where((t) => t.chatId.equals(chatId))
      ).get();

      if (rows.length > 1) {
        await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
        DebugConfig.log(DebugConfig.databaseLocal, 'updateChatCache: cleaned ${rows.length} duplicates chatId=$chatId');
        rows = [];
      }

      if (rows.isEmpty) return;

      await (db.update(db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
          .write(ChatCacheTableCompanion(
            lastMessageAt: lastMessageAt != null ? Value(lastMessageAt) : Value.absent(),
            hasUnread: hasUnread != null ? Value(hasUnread) : Value.absent(),
            otherNickname: otherNickname != null ? Value(otherNickname) : Value.absent(),
            otherAvatarUrl: otherAvatarUrl != null ? Value(otherAvatarUrl) : Value.absent(),
            lastMessage: lastMessage != null ? Value(lastMessage) : Value.absent(),
            lastMessageSender: lastMessageSender != null ? Value(lastMessageSender) : Value.absent(),
            lastMessageType: lastMessageType != null ? Value(lastMessageType) : Value.absent(),
            unreadCount: unreadCount != null ? Value(unreadCount) : Value.absent(),
            groupName: groupName != null ? Value(groupName) : Value.absent(),
            groupAvatarUrl: groupAvatarUrl != null ? Value(groupAvatarUrl) : Value.absent(),
          ));
      DebugConfig.log(DebugConfig.databaseLocal,
          'updateChatCache: written chat=$chatId otherNickname=$otherNickname');
    } catch (e) {
      DebugConfig.warn('updateChatCache failed for $chatId', data: e);
    }
  }

  Future<void> _syncChatFromFirestore(String chatId, Map<String, dynamic> data) async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      final participants = List<String>.from(data['participants'] ?? []);
      final isGroupChat = data['isGroupChat'] == true;
      if (isGroupChat) {
        await _syncGroupChatToCache(chatId, data);
        return;
      }
      final otherUid = participants.where((p) => p != uid).firstOrNull;
      if (otherUid == null) return;

      final nicknames = (data['participantNicknames'] as Map<String, dynamic>?) ?? {};
      final otherNickname = nicknames[otherUid] as String? ?? otherUid;
      DebugConfig.log(DebugConfig.repositoryResult,
          '_syncChatFromFirestore: chat=$chatId otherUid=$otherUid '
          'hasParticipantNicknames=${data.containsKey('participantNicknames')} '
          'participantNicknames=${nicknames.length} entries '
          'otherNickname=$otherNickname');
      final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
      final lastMessageBy = data['lastMessageBy'] as String?;
      final lastMessageType = data['lastMessageType'] as String? ?? 'text';
      final encryptedLastMessage = data['lastMessage'] as String?;

      String? otherAvatarUrl;
      try {
        final otherProfile = await firestore
            .collection('users').doc(otherUid).collection('public').doc('profile').get();
        otherAvatarUrl = otherProfile.data()?['avatarUrl'] as String?;
      } catch (_) {}

      String? decryptedLastMessage;
      if (encryptedLastMessage != null &&
          lastMessageType != 'system' &&
          lastMessageType != 'gif' &&
          lastMessageType != 'image' &&
          lastMessageType != 'video' &&
          lastMessageType != 'audio') {
        try {
          final key = await EncryptionUtils.getKeyOrDerive(chatId);
          decryptedLastMessage = EncryptionUtils.decryptMessage(key, encryptedLastMessage);
        } catch (e) {
          DebugConfig.warn('_syncChatFromFirestore: decrypt lastMessage failed chat=$chatId', data: e);
          decryptedLastMessage = null;
        }
      } else if (encryptedLastMessage != null) {
        decryptedLastMessage = encryptedLastMessage;
      }

      final lastMessageSender = lastMessageBy != null
          ? (lastMessageBy == uid ? 'me' : 'other')
          : null;

      var rows = await (db.select(db.chatCacheTable)
        ..where((t) => t.chatId.equals(chatId))
      ).get();

      if (rows.length > 1) {
        await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
        DebugConfig.log(DebugConfig.databaseLocal, '_syncChatFromFirestore: cleaned ${rows.length} duplicates chatId=$chatId');
        rows = [];
      }

      final unreadMap = (data['unreadCount'] as Map<String, dynamic>?) ?? {};
      final unreadCount = (unreadMap[uid] as int?) ?? 0;
      final isUnread = unreadCount > 0;
      DebugConfig.log(DebugConfig.repositoryResult, '_syncChatFromFirestore: unread count=$unreadCount chat=$chatId');

      if (rows.isNotEmpty) {
        final existing = rows.first;
        await (db.update(db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
            .write(ChatCacheTableCompanion(
              lastMessageAt: Value(lastMessageAt ?? existing.lastMessageAt),
              otherNickname: Value(otherNickname),
              otherAvatarUrl: otherAvatarUrl != null ? Value(otherAvatarUrl) : Value.absent(),
              hasUnread: Value(isUnread),
              lastMessage: decryptedLastMessage != null ? Value(decryptedLastMessage) : Value.absent(),
              lastMessageSender: lastMessageSender != null ? Value(lastMessageSender) : Value.absent(),
              lastMessageType: Value(lastMessageType),
              unreadCount: Value(unreadCount),
            ));
      } else {
        await db.into(db.chatCacheTable).insert(
          ChatCacheTableCompanion.insert(
            chatId: Value(chatId),
            ownerUid: Value(uid),
            otherUid: Value(otherUid),
            otherNickname: Value(otherNickname),
            otherAvatarUrl: Value(otherAvatarUrl),
            lastMessageAt: Value(lastMessageAt ?? DateTime.now()),
            hasUnread: Value(isUnread),
            lastMessage: decryptedLastMessage != null ? Value(decryptedLastMessage) : const Value(null),
            lastMessageSender: lastMessageSender != null ? Value(lastMessageSender) : const Value(null),
            lastMessageType: Value(lastMessageType),
            unreadCount: Value(unreadCount),
          ),
        );
        DebugConfig.log(DebugConfig.databaseLocal, '_syncChatFromFirestore: new chat cached chatId=$chatId owner=$uid');
      }
    } catch (e, s) {
      DebugConfig.error('_syncChatFromFirestore failed for $chatId', data: e, exception: s);
    }
  }

  @override
  Stream<List<ChatCacheTableData>> streamChats() async* {
    if (AuthRepository.isSigningOut) {
      DebugConfig.log(DebugConfig.chatStream, 'streamChats: blocked (signing out)');
      yield [];
      return;
    }
    final user = auth.currentUser;
    if (user == null || !AuthRepository.canUserCommunicate(user)) {
      final reason = user == null ? 'null user' : 'unverified user';
      DebugConfig.log(DebugConfig.authGuard, 'streamChats: blocked ($reason)');
      await (db.delete(db.chatCacheTable)).go();
      yield [];
      return;
    }

    final uid = user.uid;
    DebugConfig.log(DebugConfig.chatStream, 'streamChats: started for uid=$uid');

    final controller = StreamController<List<ChatCacheTableData>>();
    StreamSubscription<QuerySnapshot>? firestoreSub;
    StreamSubscription<List<ChatCacheTableData>>? driftSub;

    try {
      // ΚΡΙΣΙΜΟ FIX (Εύρημα #2): πριν διάβαζε ΟΛΑ τα chats του χρήστη σε κάθε
      // login/reconnect (unbounded query). Το .limit(150) καλύπτει άνετα τον
      // τυπικό χρήστη (no-op γι' αυτόν) και βάζει ταβάνι στο pathological
      // περιστατικό χρήστη με χιλιάδες group memberships.
      // ΣΗΜΕΙΩΣΗ: χωρίς orderBy, το Firestore επιστρέφει με σειρά __name__
      // (όχι κατ' ανάγκη τα πιο πρόσφατα 150). Αν θες σιγουρο "τα πιο πρόσφατα
      // 150 chats", πες μου και προσθέτουμε orderBy('lastMessageAt') — απαιτεί
      // μικρή αλλαγή ώστε το πεδίο να γράφεται και στη δημιουργία chat (3 σημεία).
      firestoreSub = firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .limit(150)
          .snapshots()
          .listen(
            (snapshot) async {
          bool changed = false;
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final chatId = change.doc.id;
              final isActive = FcmService.activeChatIds.contains(chatId);
              if (isActive && change.type == DocumentChangeType.modified) {
                DebugConfig.log(DebugConfig.chatStream,
                    'streamChats: lightweight sync for active chat=$chatId');
                final data = change.doc.data() as Map<String, dynamic>;
                final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
                final lastMessageBy = data['lastMessageBy'] as String?;
                final groupAvatarUrl = data['groupAvatarUrl'] as String?;
                final groupName = data['groupName'] as String?;
                final participants = List<String>.from(data['participants'] ?? []);
                final otherUid = participants.where((p) => p != uid).firstOrNull;
                final nicknames = data['participantNicknames'] as Map<String, dynamic>?;
                final avatarUrls = data['participantAvatarUrls'] as Map<String, dynamic>?;
                String? newOtherNickname;
                String? newOtherAvatarUrl;
                if (otherUid != null) {
                  newOtherNickname = nicknames?[otherUid] as String?;
                  newOtherAvatarUrl = avatarUrls?[otherUid] as String?;
                }
                DebugConfig.log(DebugConfig.chatStream,
                    'streamChats lightweight sync: chat=$chatId otherUid=$otherUid '
                    'newOtherNickname=$newOtherNickname');
                if (lastMessageAt != null || groupAvatarUrl != null || groupName != null ||
                    newOtherNickname != null || newOtherAvatarUrl != null) {
                  await updateChatCache(chatId,
                      lastMessageAt: lastMessageAt,
                      hasUnread: lastMessageBy != null && lastMessageBy != uid,
                      groupAvatarUrl: groupAvatarUrl,
                      groupName: groupName,
                      otherNickname: newOtherNickname,
                      otherAvatarUrl: newOtherAvatarUrl);
                }
              } else {
                await _syncChatFromFirestore(chatId, change.doc.data() as Map<String, dynamic>);
              }
              changed = true;
            } else if (change.type == DocumentChangeType.removed) {
              await removeChatCache(change.doc.id);
              changed = true;
            }
          }
          if (changed) {
            DebugConfig.log(DebugConfig.chatStream, 'streamChats: Firestore sync completed');
          }
        },
        onError: (e) {
          DebugConfig.warn('streamChats: Firestore listener error', data: e);
        },
      );

      driftSub = (db.select(db.chatCacheTable)
        ..where((t) => t.ownerUid.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)])
      ).watch().listen(
        controller.add,
        onError: controller.addError,
      );

      yield* controller.stream;
    } finally {
      await firestoreSub?.cancel();
      await driftSub?.cancel();
      await controller.close();
      DebugConfig.log(DebugConfig.chatStream, 'streamChats: cancelled');
    }
  }

  @override
  Future<void> sendMediaMessage(String chatId, {
    required String content,
    required String type,
    Map<String, dynamic>? replyTo,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
    int? duration,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('send_media', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (!AuthRepository.canUserCommunicate(user)) {
      throw AppException.auth('send_media', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'sendMediaMessage: chat=$chatId type=$type');

    List<String> participants = [];
    bool isGroupChat = false;
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw AppException.firestore('send_media', 'Η συνομιλία δεν βρέθηκε / Chat not found');
      }
      final data = chatDoc.data()!;
      participants = List<String>.from(data['participants'] ?? []);
      isGroupChat = data['isGroupChat'] == true;

      if (!isGroupChat) {
        final otherUid = participants.where((p) => p != user.uid).firstOrNull;
        if (otherUid != null) {
          final blockedDoc = await firestore
              .collection('users').doc(otherUid).collection('blocked').doc(user.uid)
              .get();
          if (blockedDoc.exists) {
            throw AppException.auth('send_media',
                'Δεν μπορείς να στείλεις μήνυμα σε αυτόν τον χρήστη / You cannot send messages to this user');
          }
        }
      }
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.warn('sendMediaMessage: block check failed', data: e);
    }

    try {
      final msgRef = firestore
          .collection('chats').doc(chatId).collection('messages').doc();
      final chatRef = firestore.collection('chats').doc(chatId);
      final batch = firestore.batch();

      if (imageBytes != null && type == 'image') {
        final storageRef = FirebaseStorage.instance
            .ref().child('chat_media/$chatId/${msgRef.id}.jpg');
        await storageRef.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
        content = await storageRef.getDownloadURL();
      }

      if (audioBytes != null && type == 'audio') {
        DebugConfig.log(DebugConfig.chatAudio,
            'sendMediaMessage: uploading audio chat=$chatId');
        final storageRef = FirebaseStorage.instance
            .ref().child('chat_media/$chatId/${msgRef.id}.m4a');
        await storageRef.putData(audioBytes,
            SettableMetadata(contentType: 'audio/mp4'));
        content = await storageRef.getDownloadURL();
      }

      final msgData = <String, dynamic>{
        'senderId': user.uid,
        'content': content,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        if (type == 'audio' && duration != null) 'duration': duration,
      };
      if (replyTo != null) {
        msgData['replyTo'] = replyTo;
      }
      batch.set(msgRef, msgData);

      final updateData = <String, dynamic>{
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': user.uid,
        'lastMessage': content,
        'lastMessageType': type,
      };
      for (final p in participants) {
        if (p != user.uid) {
          updateData['unreadCount.$p'] = FieldValue.increment(1);
        }
      }
      batch.update(chatRef, updateData);
      await batch.commit();

      DebugConfig.log(DebugConfig.repositoryResult, 'sendMediaMessage: success chat=$chatId type=$type');

      await updateChatCache(chatId, hasUnread: false);
    } catch (e) {
      DebugConfig.error('sendMediaMessage failed', data: e);
      throw AppException.firestore('send_media', 'Αποτυχία αποστολής / Failed to send');
    }
  }

  @override
  Future<void> syncMyProfileAcrossChats({
    required String nickname,
    String? avatarUrl,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      DebugConfig.warn('syncMyProfileAcrossChats: no auth user');
      return;
    }

    DebugConfig.log(DebugConfig.repositoryCall,
        'syncMyProfileAcrossChats: uid=$uid nickname=$nickname hasAvatar=${avatarUrl != null}');

    final chats = await getChats();
    if (chats.isEmpty) {
      DebugConfig.log(DebugConfig.firestoreRead,
          'syncMyProfileAcrossChats: Drift empty, fallback Firestore query');
      final snapshot = await firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();
      if (snapshot.docs.isEmpty) {
        DebugConfig.log(DebugConfig.repositoryResult,
            'syncMyProfileAcrossChats: no chats found');
        return;
      }
      _batchUpdateChatDocs(snapshot.docs.map((d) => d.reference).toList(),
          uid, nickname, avatarUrl);
      return;
    }

    final refs = chats
        .where((c) => c.chatId != null)
        .map((c) => firestore.collection('chats').doc(c.chatId!))
        .toList();
    _batchUpdateChatDocs(refs, uid, nickname, avatarUrl);
  }

  Future<void> _batchUpdateChatDocs(
    List<DocumentReference> refs,
    String uid,
    String nickname,
    String? avatarUrl,
  ) async {
    final updates = <String, dynamic>{
      'participantNicknames.$uid': nickname,
    };
    if (avatarUrl != null) {
      updates['participantAvatarUrls.$uid'] = avatarUrl;
    }

    const batchLimit = 500;
    var batch = firestore.batch();
    var count = 0;
    for (final ref in refs) {
      batch.update(ref, updates);
      count++;
      if (count % batchLimit == 0) {
        await batch.commit();
        batch = firestore.batch();
      }
    }
    if (count % batchLimit != 0) await batch.commit();

    DebugConfig.log(DebugConfig.firestoreWrite,
        'syncMyProfileAcrossChats: updated $count chats');
  }

  @override
  Future<void> addReaction(String chatId, String messageId, String emoji) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw AppException.auth('add_reaction', 'Δεν υπάρχει χρήστης / No user');
    if (emoji.isEmpty) throw AppException.validation('emoji');

    DebugConfig.log(DebugConfig.chatReactions, 'addReaction: chat=$chatId msg=$messageId emoji=$emoji uid=$uid');

    try {
      await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .update({'reactions.$uid': emoji});
      DebugConfig.log(DebugConfig.firestoreWrite, 'addReaction: success chat=$chatId msg=$messageId');
    } catch (e) {
      DebugConfig.error('addReaction failed', data: e);
      throw AppException.firestore('add_reaction', 'Αποτυχία αποθήκευσης / Failed to save reaction');
    }
  }

  @override
  Future<void> removeReaction(String chatId, String messageId) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw AppException.auth('remove_reaction', 'Δεν υπάρχει χρήστης / No user');

    DebugConfig.log(DebugConfig.chatReactions, 'removeReaction: chat=$chatId msg=$messageId uid=$uid');

    try {
      await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .update({'reactions.$uid': FieldValue.delete()});
      DebugConfig.log(DebugConfig.firestoreWrite, 'removeReaction: success chat=$chatId msg=$messageId');
    } catch (e) {
      DebugConfig.error('removeReaction failed', data: e);
      throw AppException.firestore('remove_reaction', 'Αποτυχία αφαίρεσης / Failed to remove reaction');
    }
  }

  @override
  Future<void> deleteChat(String chatId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deleteChat: delegating to requestDeleteChat chat=$chatId');
    await requestDeleteChat(chatId);
  }

  @override
  Future<void> removeChatCache(String chatId) async {
    try {
      await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      DebugConfig.log(DebugConfig.databaseLocal, 'removeChatCache: removed chat=$chatId');
    } catch (e) {
      DebugConfig.warn('removeChatCache failed for $chatId', data: e);
    }
  }

  Future<void> logConsent(String uid, String otherUid) async {
    try {
      await db.into(db.consentLogTable).insert(
        ConsentLogTableCompanion.insert(
          uid: Value(uid),
          action: Value('sent_request'),
          dataType: Value('chat'),
          details: Value('Started chat with $otherUid / Έναρξη συνομιλίας με $otherUid'),
        ),
      );
      DebugConfig.log(DebugConfig.consentLogWrite, 'createChat consent logged: other=$otherUid');
    } catch (e, s) {
      DebugConfig.error('createChat consent log failed', data: e, exception: s);
    }
  }
}

Future<void> deleteAllChatMedia(String chatId) async {
  DebugConfig.log(DebugConfig.storageUpload, 'deleteAllChatMedia: $chatId');
  try {
    final ref = FirebaseStorage.instance.ref().child('chat_media/$chatId');
    final result = await ref.listAll();
    if (result.items.isNotEmpty) {
      await Future.wait(result.items.map((item) => item.delete()));
      DebugConfig.log(DebugConfig.storageUpload, 'deleteAllChatMedia: deleted ${result.items.length} files for $chatId');
    }
  } catch (e) {
    DebugConfig.warn('deleteAllChatMedia failed (non-fatal)', data: e);
  }
}
