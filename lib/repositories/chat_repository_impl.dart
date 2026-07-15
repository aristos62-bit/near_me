import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
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

part 'group_chat_mixin.dart';
part 'chat_repository_delete.dart';
part 'chat_repository_clear.dart';

class ChatRepositoryImpl with GroupChatMixin, ChatDeleteMixin, ChatClearMixin implements ChatRepository {
  @override
  final FirebaseFirestore firestore;
  @override
  final FirebaseAuth auth;
  @override
  final AppDatabase db;

  // Cache αποκρυπτογραφημένων messages — αποφυγή re-decrypt σε κάθε Firestore snapshot
  final Map<String, Map<String, String>> _messageEncryptCache = {};
  final Map<String, Map<String, String>> _messageDecryptCache = {};

  @override
  Map<String, Map<String, String>> get messageEncryptCache => _messageEncryptCache;
  @override
  Map<String, Map<String, String>> get messageDecryptCache => _messageDecryptCache;

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
  Future<void> sendMessage(String chatId, String content) async {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('send_message', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'sendMessage: blocked unverified user');
      throw AppException.auth('send_message', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να στείλεις μήνυμα / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'sendMessage: chat=$chatId');

    List<String>? validMentions;
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw AppException.firestore('send_message', 'Η συνομιλία δεν βρέθηκε / Chat not found');
      }
      final data = chatDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final isGroupChat = data['isGroupChat'] == true;

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
      batch.set(msgRef, msgData);
      batch.update(chatRef, {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': user.uid,
        'lastMessage': encrypted,
        'lastMessageType': 'text',
      });
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

  @override
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) {
    DebugConfig.log(DebugConfig.chatStream, 'messagesStream: starting listener chat=$chatId');

    final stream = firestore
        .collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          DebugConfig.log(DebugConfig.chatStream,
              'messagesStream snapshot: ${snapshot.docs.length} docs chat=$chatId');
          return snapshot;
        })
        .asyncMap((snapshot) async {
          final key = await EncryptionUtils.getKeyOrDerive(chatId);
          final encCache = _messageEncryptCache.putIfAbsent(chatId, () => {});
          final decCache = _messageDecryptCache.putIfAbsent(chatId, () => {});
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final encrypted = data['content'] as String? ?? '';
            final docId = doc.id;
            final type = data['type'] as String? ?? 'text';

            String decrypted;
            if (type == 'system') {
              decrypted = encrypted;
              DebugConfig.log(DebugConfig.chatStream, 'system message: $docId content=$encrypted');
            } else if (encCache[docId] == encrypted && decCache.containsKey(docId)) {
              decrypted = decCache[docId]!;
              DebugConfig.log(DebugConfig.chatEncrypt, 'decrypt cache hit: msg=$docId');
            } else {
              try {
                decrypted = EncryptionUtils.decryptMessage(key, encrypted);
                encCache[docId] = encrypted;
                decCache[docId] = decrypted;
                DebugConfig.log(DebugConfig.chatEncrypt, 'decrypt cache miss: msg=$docId');
              } catch (e) {
                encCache.remove(docId);
                decCache.remove(docId);
                try {
                  final fallbackKey = EncryptionUtils.deriveKey(chatId);
                  decrypted = EncryptionUtils.decryptMessage(fallbackKey, encrypted);
                  encCache[docId] = encrypted;
                  decCache[docId] = decrypted;
                  DebugConfig.log(DebugConfig.chatEncrypt, 'messagesStream: decrypt with derived key succeeded for msg $docId');
                } catch (_) {
                  DebugConfig.warn('messagesStream: decrypt failed for msg $docId', data: e);
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
              'seenBy': (data['seenBy'] as List?)?.cast<String>() ?? <String>[],
              'mentions': (data['mentions'] as List?)?.cast<String>() ?? <String>[],
              'action': data['action'] as String?,
              'contentEn': data['contentEn'] as String?,
            };
          }).toList();
        });

    DebugConfig.log(DebugConfig.chatStream, 'messagesStream: listener active chat=$chatId');
    return stream;
  }

  @override
  Future<void> markAsRead(String chatId, {bool isGroupChat = false}) async {
    final user = auth.currentUser;
    if (user == null) return;

    DebugConfig.log(DebugConfig.repositoryCall, 'markAsRead: chat=$chatId isGroup=$isGroupChat');

    try {
      await firestore.collection('chats').doc(chatId).update({
        'lastReadTimestamps.${user.uid}': FieldValue.serverTimestamp(),
      });

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
      if (encryptedLastMessage != null) {
        try {
          final key = await EncryptionUtils.getKeyOrDerive(chatId);
          decryptedLastMessage = EncryptionUtils.decryptMessage(key, encryptedLastMessage);
        } catch (e) {
          DebugConfig.warn('_syncChatFromFirestore: decrypt lastMessage failed chat=$chatId', data: e);
          decryptedLastMessage = null;
        }
      }

      final isUnread = lastMessageBy != null && lastMessageBy != uid;
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

      int unreadCount = rows.isNotEmpty ? rows.first.unreadCount : 0;
      if (isUnread) {
        final isNewMessage = rows.isEmpty ||
            (lastMessageAt != null && rows.first.lastMessageAt != null &&
                lastMessageAt.isAfter(rows.first.lastMessageAt!));
        if (isNewMessage) {
          try {
            final count = await firestore
                .collection('chats').doc(chatId).collection('messages')
                .where('senderId', isNotEqualTo: uid)
                .where('isRead', isEqualTo: false)
                .count().get();
            unreadCount = count.count ?? 0;
            DebugConfig.log(DebugConfig.repositoryResult, '_syncChatFromFirestore: unread count=$unreadCount chat=$chatId');
          } catch (_) {
            unreadCount = rows.isNotEmpty ? rows.first.unreadCount + 1 : 1;
            DebugConfig.warn('_syncChatFromFirestore: count query failed, heuristic fallback chat=$chatId');
          }
        }
      } else {
        unreadCount = 0;
      }

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
      firestoreSub = firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
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
                if (lastMessageAt != null || groupAvatarUrl != null || groupName != null) {
                  await updateChatCache(chatId,
                      lastMessageAt: lastMessageAt,
                      hasUnread: lastMessageBy != null && lastMessageBy != uid,
                      groupAvatarUrl: groupAvatarUrl,
                      groupName: groupName);
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
