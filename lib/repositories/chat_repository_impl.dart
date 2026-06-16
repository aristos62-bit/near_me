import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drift/drift.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import 'chat_repository.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/encryption_utils.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AppDatabase _db;

  ChatRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AppDatabase? db,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? DatabaseService.instance;

  @override
  Future<String> createChat(String otherUid) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('create_chat', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (user.isAnonymous) {
      DebugConfig.log(DebugConfig.repositoryCall, 'createChat: blocked anonymous user');
      throw AppException.auth('create_chat', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να ξεκινήσεις συνομιλία / You must verify your account');
    }

    final uid = user.uid;

    try {
      final blockedDoc = await _firestore
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
      await _ensureKeyDerived(existing);
      return existing;
    }

    final myProfile = await _firestore
        .collection('users').doc(uid).collection('public').doc('profile').get();
    final myNickname = myProfile.data()?['nickname'] as String? ?? uid;
    final otherProfile = await _firestore
        .collection('users').doc(otherUid).collection('public').doc('profile').get();
    final otherNickname = otherProfile.data()?['nickname'] as String? ?? otherUid;

    final chatId = _firestore.collection('chats').doc().id;
    final key = EncryptionUtils.deriveKey(chatId);
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [uid, otherUid],
      'participantNicknames': {uid: myNickname, otherUid: otherNickname},
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
    DebugConfig.log(DebugConfig.repositoryResult, 'createChat: new chat created: $chatId');

    await EncryptionUtils.storeKey(chatId, key);
    await _saveChatCache(chatId, otherUid, null);
    await _logConsent(uid, otherUid);

    return chatId;
  }

  Future<void> _ensureKeyDerived(String chatId) async {
    final stored = await EncryptionUtils.getKey(chatId);
    final derived = EncryptionUtils.deriveKey(chatId);
    if (stored == null || stored.base64 != derived.base64) {
      DebugConfig.log(DebugConfig.chatEncrypt, 'ensureKeyDerived: migrating to derived key chat=$chatId');
      await EncryptionUtils.storeKey(chatId, derived);
    }
  }

  Future<String?> _findExistingChat(String uid1, String uid2) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid1)
          .get();

      for (final doc in snapshot.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(uid2)) {
          return doc.id;
        }
      }
    } catch (e) {
      DebugConfig.warn('createChat: findExisting failed', data: e);
    }
    return null;
  }

  @override
  Future<void> sendMessage(String chatId, String content) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('send_message', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (user.isAnonymous) {
      DebugConfig.log(DebugConfig.repositoryCall, 'sendMessage: blocked anonymous user');
      throw AppException.auth('send_message', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να στείλεις μήνυμα / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'sendMessage: chat=$chatId');

    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw AppException.firestore('send_message', 'Η συνομιλία δεν βρέθηκε / Chat not found');
      }
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherUid = participants.where((p) => p != user.uid).firstOrNull;
      if (otherUid != null) {
        final blockedDoc = await _firestore
            .collection('users').doc(otherUid).collection('blocked').doc(user.uid)
            .get();
        if (blockedDoc.exists) {
          DebugConfig.log(DebugConfig.repositoryCall, 'sendMessage: blocked by $otherUid');
          throw AppException.auth('send_message',
              'Δεν μπορείς να στείλεις μήνυμα σε αυτόν τον χρήστη / You cannot send messages to this user');
        }
      }
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.warn('sendMessage: block check failed (non-fatal)', data: e);
    }

    await _ensureKeyDerived(chatId);
    final key = await EncryptionUtils.getKey(chatId);
    if (key == null) {
      throw AppException(
        message: 'Το κλειδί κρυπτογράφησης δεν βρέθηκε / Encryption key not found',
        code: 'encryption_key_missing',
      );
    }

    try {
      final encrypted = EncryptionUtils.encryptMessage(key, content);

      final msgRef = _firestore
          .collection('chats').doc(chatId).collection('messages').doc();
      final chatRef = _firestore.collection('chats').doc(chatId);
      final batch = _firestore.batch();

      batch.set(msgRef, {
        'senderId': user.uid,
        'content': encrypted,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      final lastMessageEncrypted = EncryptionUtils.encryptMessage(key, content);
      batch.update(chatRef, {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': user.uid,
        'lastMessage': lastMessageEncrypted,
        'lastMessageType': 'text',
      });
      await batch.commit();

      DebugConfig.log(DebugConfig.repositoryResult, 'sendMessage: success chat=$chatId');

      await _updateChatCache(chatId, hasUnread: false);
    } catch (e) {
      DebugConfig.error('sendMessage failed', data: e);
      throw AppException.firestore('send_message', 'Αποτυχία αποστολής μηνύματος / Failed to send message');
    }
  }

  @override
  Future<List<ChatCacheTableData>> getChats() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'getChats');
    try {
      final chats = await (_db.select(_db.chatCacheTable)
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

    final stream = _firestore
        .collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          DebugConfig.log(DebugConfig.chatStream,
              'messagesStream snapshot: ${snapshot.docs.length} docs chat=$chatId');
          return snapshot;
        })
        .asyncMap((snapshot) async {
          await _ensureKeyDerived(chatId);
          final key = await EncryptionUtils.getKey(chatId);
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final encrypted = data['content'] as String? ?? '';
            String decrypted;
            if (key != null) {
              try {
                decrypted = EncryptionUtils.decryptMessage(key, encrypted);
              } catch (e) {
                try {
                  final fallbackKey = EncryptionUtils.deriveKey(chatId);
                  decrypted = EncryptionUtils.decryptMessage(fallbackKey, encrypted);
                  DebugConfig.log(DebugConfig.chatEncrypt, 'messagesStream: decrypt with derived key succeeded for msg ${doc.id}');
                } catch (_) {
                  DebugConfig.warn('messagesStream: decrypt failed for msg ${doc.id}', data: e);
                  decrypted = encrypted;
                }
              }
            } else {
              decrypted = encrypted;
            }
            return {
              'id': doc.id,
              'senderId': data['senderId'] ?? '',
              'content': decrypted,
              'type': data['type'] ?? 'text',
              'timestamp': data['timestamp'],
              'isRead': data['isRead'] ?? false,
            };
          }).toList();
        });

    DebugConfig.log(DebugConfig.chatStream, 'messagesStream: listener active chat=$chatId');
    return stream;
  }

  @override
  Future<void> markAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    DebugConfig.log(DebugConfig.repositoryCall, 'markAsRead: chat=$chatId');

    try {
      final unread = await _firestore
          .collection('chats').doc(chatId).collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      final docs = unread.docs.where((d) => d.data()['senderId'] != user.uid).toList();

      if (docs.isEmpty) {
        DebugConfig.log(DebugConfig.repositoryResult, 'markAsRead: no unread messages chat=$chatId');
        return;
      }
      final batch = _firestore.batch();
      for (final doc in docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      DebugConfig.log(DebugConfig.repositoryResult, 'markAsRead: marked ${docs.length} messages chat=$chatId');

      await (_db.update(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
          .write(const ChatCacheTableCompanion(hasUnread: Value(false), unreadCount: Value(0)));
      DebugConfig.log(DebugConfig.databaseLocal, 'markAsRead: cache updated chat=$chatId');
    } catch (e) {
      DebugConfig.error('markAsRead failed', data: e);
      throw AppException.firestore('mark_read', 'Αποτυχία ενημέρωσης / Failed to mark as read');
    }
  }

  Future<void> _saveChatCache(String chatId, String otherUid, DateTime? lastMessageAt) async {
    try {
      final otherProfile = await _firestore
          .collection('users').doc(otherUid).collection('public').doc('profile').get();
      final otherNickname = otherProfile.data()?['nickname'] as String? ?? otherUid;
      final otherAvatarUrl = otherProfile.data()?['avatarUrl'] as String?;

      await _db.into(_db.chatCacheTable).insert(
        ChatCacheTableCompanion.insert(
          chatId: Value(chatId),
          otherUid: Value(otherUid),
          otherNickname: Value(otherNickname),
          otherAvatarUrl: Value(otherAvatarUrl),
          lastMessageAt: Value(lastMessageAt ?? DateTime.now()),
          hasUnread: const Value(false),
        ),
      );
      DebugConfig.log(DebugConfig.databaseLocal, 'createChat: cache saved chat=$chatId');
    } catch (e) {
      DebugConfig.warn('createChat: cache save failed', data: e);
    }
  }

  Future<void> _updateChatCache(String chatId, {DateTime? lastMessageAt, bool? hasUnread, String? otherNickname, String? otherAvatarUrl, String? lastMessage, String? lastMessageSender, String? lastMessageType, int? unreadCount}) async {
    try {
      final rows = await (_db.select(_db.chatCacheTable)
        ..where((t) => t.chatId.equals(chatId))
      ).get();

      if (rows.length > 1) {
        await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
        DebugConfig.log(DebugConfig.databaseLocal, '_updateChatCache: cleaned ${rows.length} duplicates chatId=$chatId');
      }

      if (rows.isEmpty) return;

      await (_db.update(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
          .write(ChatCacheTableCompanion(
            lastMessageAt: lastMessageAt != null ? Value(lastMessageAt) : Value.absent(),
            hasUnread: hasUnread != null ? Value(hasUnread) : Value.absent(),
            otherNickname: otherNickname != null ? Value(otherNickname) : Value.absent(),
            otherAvatarUrl: otherAvatarUrl != null ? Value(otherAvatarUrl) : Value.absent(),
            lastMessage: lastMessage != null ? Value(lastMessage) : Value.absent(),
            lastMessageSender: lastMessageSender != null ? Value(lastMessageSender) : Value.absent(),
            lastMessageType: lastMessageType != null ? Value(lastMessageType) : Value.absent(),
            unreadCount: unreadCount != null ? Value(unreadCount) : Value.absent(),
          ));
    } catch (e) {
      DebugConfig.warn('_updateChatCache failed for $chatId', data: e);
    }
  }

  Future<void> _syncChatFromFirestore(String chatId, Map<String, dynamic> data) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final participants = List<String>.from(data['participants'] ?? []);
      final otherUid = participants.where((p) => p != uid).firstOrNull;
      if (otherUid == null) return;

      final nicknames = (data['participantNicknames'] as Map<String, dynamic>?) ?? {};
      final otherNickname = nicknames[otherUid] as String? ?? otherUid;
      final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
      final lastMessageBy = data['lastMessageBy'] as String?;
      final lastMessageType = data['lastMessageType'] as String? ?? 'text';
      final encryptedLastMessage = data['lastMessage'] as String?;

      String? otherAvatarUrl;
      try {
        final otherProfile = await _firestore
            .collection('users').doc(otherUid).collection('public').doc('profile').get();
        otherAvatarUrl = otherProfile.data()?['avatarUrl'] as String?;
      } catch (_) {}

      String? decryptedLastMessage;
      if (encryptedLastMessage != null) {
        try {
          final key = await EncryptionUtils.getKey(chatId);
          if (key != null) {
            decryptedLastMessage = EncryptionUtils.decryptMessage(key, encryptedLastMessage);
            DebugConfig.log(DebugConfig.chatEncrypt, '_syncChatFromFirestore: decrypted lastMessage chat=$chatId');
          } else {
            final fallbackKey = EncryptionUtils.deriveKey(chatId);
            decryptedLastMessage = EncryptionUtils.decryptMessage(fallbackKey, encryptedLastMessage);
            DebugConfig.log(DebugConfig.chatEncrypt, '_syncChatFromFirestore: decrypted with derived key chat=$chatId');
          }
        } catch (e) {
          DebugConfig.warn('_syncChatFromFirestore: decrypt lastMessage failed chat=$chatId', data: e);
          decryptedLastMessage = null;
        }
      }

      final isUnread = lastMessageBy != null && lastMessageBy != uid;
      final lastMessageSender = lastMessageBy != null
          ? (lastMessageBy == uid ? 'me' : 'other')
          : null;

      final rows = await (_db.select(_db.chatCacheTable)
        ..where((t) => t.chatId.equals(chatId))
      ).get();

      if (rows.length > 1) {
        await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
        DebugConfig.log(DebugConfig.databaseLocal, '_syncChatFromFirestore: cleaned ${rows.length} duplicates chatId=$chatId');
      }

      int unreadCount = rows.isNotEmpty ? rows.first.unreadCount : 0;
      if (isUnread) {
        final isNewMessage = rows.isEmpty ||
            (lastMessageAt != null && rows.first.lastMessageAt != null &&
                lastMessageAt.isAfter(rows.first.lastMessageAt!));
        if (isNewMessage) {
          try {
            final count = await _firestore
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
        await (_db.update(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
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
        await _db.into(_db.chatCacheTable).insert(
          ChatCacheTableCompanion.insert(
            chatId: Value(chatId),
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
        DebugConfig.log(DebugConfig.databaseLocal, '_syncChatFromFirestore: new chat cached chatId=$chatId');
      }
    } catch (e, s) {
      DebugConfig.error('_syncChatFromFirestore failed for $chatId', data: e, exception: s);
    }
  }

  @override
  Stream<List<ChatCacheTableData>> streamChats() async* {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      final msg = user == null ? 'no authenticated user' : 'anonymous user';
      DebugConfig.log(DebugConfig.chatStream, 'streamChats: $msg');
      await (_db.delete(_db.chatCacheTable)).go();
      yield [];
      return;
    }

    final uid = user.uid;
    DebugConfig.log(DebugConfig.chatStream, 'streamChats: started for uid=$uid');

    StreamSubscription<QuerySnapshot>? firestoreSub;
    try {
      firestoreSub = _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .snapshots()
          .listen(
            (snapshot) async {
              bool changed = false;
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added ||
                    change.type == DocumentChangeType.modified) {
                  await _syncChatFromFirestore(change.doc.id, change.doc.data() as Map<String, dynamic>);
                  changed = true;
                } else if (change.type == DocumentChangeType.removed) {
                  await _removeChatCache(change.doc.id);
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

      await for (final rows in (_db.select(_db.chatCacheTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)])
        ).watch()) {
        yield rows;
      }
    } finally {
      await firestoreSub?.cancel();
      DebugConfig.log(DebugConfig.chatStream, 'streamChats: cancelled');
    }
  }

  @override
  Future<void> deleteChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('delete_chat', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');

    DebugConfig.log(DebugConfig.repositoryCall, 'deleteChat: deleting chat=$chatId');

    try {
      final messages = await _firestore
          .collection('chats').doc(chatId).collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('chats').doc(chatId));
      await batch.commit();

      await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      await EncryptionUtils.deleteKey(chatId);

      DebugConfig.log(DebugConfig.repositoryResult, 'deleteChat: done chat=$chatId');
    } catch (e) {
      DebugConfig.warn('deleteChat failed, cleaning local cache', data: e);
      await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      await EncryptionUtils.deleteKey(chatId);
      throw AppException.firestore('delete_chat', 'Αποτυχία διαγραφής συνομιλίας / Failed to delete chat');
    }
  }

  @override
  Future<void> clearMessages(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('clear_messages', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');

    DebugConfig.log(DebugConfig.repositoryCall, 'clearMessages: clearing messages chat=$chatId');

    try {
      final messages = await _firestore
          .collection('chats').doc(chatId).collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      DebugConfig.log(DebugConfig.repositoryResult, 'clearMessages: done chat=$chatId');
    } catch (e) {
      DebugConfig.error('clearMessages failed', data: e);
      throw AppException.firestore('clear_messages', 'Αποτυχία διαγραφής μηνυμάτων / Failed to clear messages');
    }
  }

  Future<void> _removeChatCache(String chatId) async {
    try {
      await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      DebugConfig.log(DebugConfig.databaseLocal, 'removeChatCache: removed chat=$chatId');
    } catch (e) {
      DebugConfig.warn('removeChatCache failed for $chatId', data: e);
    }
  }

  Future<void> _logConsent(String uid, String otherUid) async {
    try {
      await _db.into(_db.consentLogTable).insert(
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
