import 'dart:async';
import 'dart:io';
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
import '../core/config/feature_flags.dart';
import '../core/debug/debug_config.dart';
import '../core/services/vision_moderation_service.dart';
import '../core/notifications/fcm_service.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/encryption_utils.dart';
import '../core/utils/storage_helpers.dart';
import '../shared/utils/image_utils.dart';
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

  // Equality cache για streamChats — αποφυγή redundant emits όταν το Drift
  // .watch() ξανα-εκπέμπει ίδια λίστα (π.χ. bulk sync στο startup).
  List<ChatCacheTableData>? _lastChatsListCache;
  String? _lastChatsStreamUid;

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
    // Tier 1 — τοπικό Drift cache (άμεσο, offline, χωρίς Firestore rules).
    // Το cache συμπληρώνεται από streamChats() → _syncChatFromFirestore
    // (γράφει ownerUid + otherUid). Ταξινομούμε κατά lastMessageAt desc ώστε,
    // αν από παλιό bug υπάρχουν duplicate chats με τον ίδιο άνθρωπο, να
    // προτιμηθεί αυτό με δραστηριότητα (το κενό duplicate έχει null).
    try {
      final cached = await (db.select(db.chatCacheTable)
        ..where((t) =>
            t.ownerUid.equals(uid1) &
            t.otherUid.equals(uid2) &
            t.isGroupChat.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)])
        ..limit(1)).get();
      if (cached.isNotEmpty && cached.first.chatId != null) {
        DebugConfig.log(DebugConfig.repositoryResult,
            '_findExistingChat: Tier 1 cache hit chat=${cached.first.chatId}');
        return cached.first.chatId;
      }
    } catch (e) {
      DebugConfig.warn('_findExistingChat: Tier 1 (local cache) failed', data: e);
    }

    // Tier 2 — Firestore scan με 'participants arrayContains' (rules-compatible,
    // ίδιο pattern με το streamChats). Καλύπτει την περίπτωση που το cache είναι
    // ακόμα άδειο (π.χ. νέα εγκατάσταση / άλλη συσκευή).
    try {
      DebugConfig.log(DebugConfig.repositoryCall,
          '_findExistingChat: Tier 2 Firestore scan uid1=$uid1');
      final snapshot = await firestore
          .collection('chats')
          .where('participants', arrayContains: uid1)
          .limit(150)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isGroupChat'] == true) {
          DebugConfig.log(DebugConfig.repositoryResult,
              '_findExistingChat: skip group chat=${doc.id} for 1-on-1 lookup');
          continue;
        }
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.length != 2 || !participants.contains(uid2)) continue;
        DebugConfig.log(DebugConfig.repositoryResult,
            '_findExistingChat: Tier 2 hit chat=${doc.id}');
        return doc.id;
      }
    } catch (e) {
      DebugConfig.warn('_findExistingChat: Tier 2 (Firestore scan) failed', data: e);
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
    String messageExpiry = 'off';
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw AppException.firestore('send_message', 'Η συνομιλία δεν βρέθηκε / Chat not found');
      }
      final data = chatDoc.data()!;
      participants = List<String>.from(data['participants'] ?? []);
      isGroupChat = data['isGroupChat'] == true;
      messageExpiry = data['messageExpiry'] as String? ?? 'off';

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
      if (messageExpiry != 'off') {
        final duration = _expiryDuration(messageExpiry);
        if (duration != null) {
          msgData['expiresAt'] = Timestamp.fromDate(DateTime.now().add(duration));
        }
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
    } catch (e, s) {
      DebugConfig.error('sendMessage failed',
          data: e, stack: s, reportToCrashlytics: true);
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
      'thumbnailUrl': data['thumbnailUrl'] as String?,
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

      final avatarUrls = data['participantAvatarUrls'] as Map<String, dynamic>?;
      final otherAvatarUrl = avatarUrls?[otherUid] as String?;

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

    // Reset equality cache όταν αλλάζει ο χρήστης (αποφυγή stale equality)
    if (_lastChatsStreamUid != uid) {
      _lastChatsListCache = null;
      _lastChatsStreamUid = uid;
    }

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
        (rows) {
          // Equality-caching, ίδιο pattern με messagesStream/chatDocProvider:
          // αν η νέα λίστα είναι ίδια με την προηγούμενη, suppress το emit.
          final previous = _lastChatsListCache;
          if (previous != null && const DeepCollectionEquality().equals(previous, rows)) {
            DebugConfig.log(DebugConfig.chatStream,
                'streamChats: suppressed (content unchanged) rows=${rows.length}');
            return;
          }
          _lastChatsListCache = rows;
          controller.add(rows);
        },
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
    String? videoPath,
    Uint8List? thumbnailBytes,
    String? forwardThumbnailUrl,
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
    String messageExpiry = 'off';
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw AppException.firestore('send_media', 'Η συνομιλία δεν βρέθηκε / Chat not found');
      }
      final data = chatDoc.data()!;
      participants = List<String>.from(data['participants'] ?? []);
      isGroupChat = data['isGroupChat'] == true;
      messageExpiry = data['messageExpiry'] as String? ?? 'off';

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

      if (imageBytes != null && (type == 'image' || type == 'gif')) {
        if (FeatureFlags.contentModerationEnabled && FeatureFlags.autoModerateChatMedia) {
          final safe = await VisionModerationService.isChatMediaSafe(imageBytes);
          if (!safe) {
            DebugConfig.log(DebugConfig.moderation, 'sendMediaMessage blocked by moderation: chat=$chatId type=$type');
            throw AppException(message: 'Moderation rejected image', code: 'moderation/blocked-explicit');
          }
        }
        final isGif = type == 'gif';
        DebugConfig.log(DebugConfig.storageUpload,
            'sendMediaMessage: uploading image chat=$chatId type=$type');
        final storageRef = FirebaseStorage.instance
            .ref().child('chat_media/$chatId/${msgRef.id}.${isGif ? 'gif' : 'jpg'}');
        await StorageHelpers.uploadBytesWithTimeout(storageRef, imageBytes,
            contentType: isGif ? 'image/gif' : 'image/jpeg', type: isGif ? 'gif' : 'image');
        content = await StorageHelpers.downloadUrlWithTimeout(storageRef);
      }

      if (audioBytes != null && type == 'audio') {
        DebugConfig.log(DebugConfig.chatAudio,
            'sendMediaMessage: uploading audio chat=$chatId');
        final storageRef = FirebaseStorage.instance
            .ref().child('chat_media/$chatId/${msgRef.id}.m4a');
        await StorageHelpers.uploadBytesWithTimeout(storageRef, audioBytes,
            contentType: 'audio/mp4', type: 'audio');
        content = await StorageHelpers.downloadUrlWithTimeout(storageRef);
      }

      String? thumbnailUrl;
      if (videoPath != null && type == 'video') {
        if (FeatureFlags.contentModerationEnabled &&
            FeatureFlags.autoModerateChatVideoThumbnail) {
          if (thumbnailBytes != null) {
            final safe = await VisionModerationService.isChatMediaSafe(thumbnailBytes);
            if (!safe) {
              DebugConfig.log(DebugConfig.moderation,
                  'sendMediaMessage blocked by moderation (video thumbnail): chat=$chatId');
              throw AppException(
                  message: 'Moderation rejected video',
                  code: 'moderation/blocked-explicit-video');
            }
          } else {
            DebugConfig.log(DebugConfig.moderation,
                'sendMediaMessage: video moderation skipped (no thumbnail) chat=$chatId — fail-open');
          }
        }
        DebugConfig.log(DebugConfig.chatVideo,
            'sendMediaMessage: uploading video chat=$chatId');
        final storageRef = FirebaseStorage.instance
            .ref().child('chat_media/$chatId/${msgRef.id}.mp4');
        final file = File(videoPath);
        final task = storageRef.putFile(file,
            SettableMetadata(contentType: 'video/mp4'));
        await StorageHelpers.uploadFileWithTimeout(task,
            'chat_media/$chatId/${msgRef.id}.mp4',
            timeout: StorageHelpers.timeoutFor('video'));
        content = await StorageHelpers.downloadUrlWithTimeout(storageRef);

        if (thumbnailBytes != null) {
          try {
            final thumbRef = FirebaseStorage.instance
                .ref().child('chat_media/$chatId/${msgRef.id}_thumb.jpg');
            await StorageHelpers.uploadBytesWithTimeout(thumbRef, thumbnailBytes,
                contentType: 'image/jpeg', type: 'thumb');
            thumbnailUrl = await StorageHelpers.downloadUrlWithTimeout(thumbRef);
          } catch (e) {
            DebugConfig.warn('sendMediaMessage: thumbnail upload failed', data: e);
          }
        }
      }

      if (type == 'video' && forwardThumbnailUrl != null) {
        DebugConfig.log(DebugConfig.chatVideo,
            'sendMediaMessage: forward thumbnail passthrough for video');
      }

      final msgData = <String, dynamic>{
        'senderId': user.uid,
        'content': content,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        if ((type == 'audio' || type == 'video') && duration != null) 'duration': duration,
        if (type == 'video' && (thumbnailUrl != null || forwardThumbnailUrl != null))
          'thumbnailUrl': thumbnailUrl ?? forwardThumbnailUrl,
      };
      if (replyTo != null) {
        msgData['replyTo'] = replyTo;
      }
      if (messageExpiry != 'off') {
        final duration = _expiryDuration(messageExpiry);
        if (duration != null) {
          msgData['expiresAt'] = Timestamp.fromDate(DateTime.now().add(duration));
        }
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
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('sendMediaMessage failed',
          data: e, stack: s, reportToCrashlytics: true);
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
      // ── Block check (ίδιο pattern με sendMessage) ──────────────
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        if (data['isGroupChat'] != true) {
          final otherUid = participants.where((p) => p != uid).firstOrNull;
          if (otherUid != null) {
            final blockedDoc = await firestore
                .collection('users').doc(otherUid).collection('blocked').doc(uid)
                .get();
            if (blockedDoc.exists) {
              DebugConfig.log(DebugConfig.chatReactions, 'addReaction: blocked by $otherUid');
              throw AppException.auth('add_reaction',
                  'Δεν μπορείς να αντιδράσεις σε αυτό το μήνυμα / You cannot react to this message');
            }
          }
        }
      }
      // ───────────────────────────────────────────────────────────

      await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .update({'reactions.$uid': emoji});
      DebugConfig.log(DebugConfig.firestoreWrite, 'addReaction: success chat=$chatId msg=$messageId');
    } catch (e) {
      if (e is AppException) rethrow;
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

  Duration? _expiryDuration(String value) {
    return switch (value) {
      '1min' => const Duration(minutes: 1),
      '5min' => const Duration(minutes: 5),
      '30min' => const Duration(minutes: 30),
      '6h' => const Duration(hours: 6),
      '12h' => const Duration(hours: 12),
      '24h' => const Duration(hours: 24),
      _ => null,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsersByNickname(String query, {int limit = 50}) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'searchUsersByNickname: query=$query');
    try {
      final lowerQuery = query.trim().toLowerCase();
      if (lowerQuery.isEmpty) return [];
      final snap = await firestore
          .collectionGroup('public')
          .where('isVisible', isEqualTo: true)
          .where('nicknameLowercase', isGreaterThanOrEqualTo: lowerQuery)
          .where('nicknameLowercase', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .orderBy('nicknameLowercase')
          .limit(limit)
          .get();
      // Curated πεδία μόνο — το 'public' doc μπορεί να περιέχει email/phone
      // (αν showEmail/showPhone === true), δεν πρέπει να φεύγουν από το repository.
      final results = snap.docs.map((doc) {
        final data = doc.data();
        final uid = data['uid'] as String? ?? doc.id;
        return <String, dynamic>{
          'uid': uid,
          'nickname': data['nickname'] as String? ?? uid,
          'avatarUrl': data['avatarUrl'] as String?,
          'age': data['age'] as int?,
          'city': data['city'] as String?,
        };
      }).toList();
      DebugConfig.log(DebugConfig.repositoryResult, 'searchUsersByNickname: ${results.length} results');
      return results;
    } on FirebaseException catch (e) {
      DebugConfig.error('searchUsersByNickname failed', data: e.message ?? e.code);
      throw AppException.firestore('search_users', e);
    }
  }

  @override
  Stream<DocumentSnapshot?> chatDocStream(String chatId) {
    DebugConfig.log(DebugConfig.firestoreStream, 'chatDocStream created: $chatId');
    return firestore.collection('chats').doc(chatId).snapshots();
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
