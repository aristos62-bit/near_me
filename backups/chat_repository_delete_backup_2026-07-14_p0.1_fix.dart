part of 'chat_repository_impl.dart';

mixin ChatDeleteMixin {
  FirebaseFirestore get firestore;
  FirebaseAuth get auth;
  AppDatabase get db;
  Future<void> removeChatCache(String chatId);

  Future<void> deleteGroup(String chatId);
  Map<String, Map<String, String>> get messageEncryptCache;
  Map<String, Map<String, String>> get messageDecryptCache;

  String get _deleteUid {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('auth_required', 'Δεν υπάρχει χρήστης / No user');
    return user.uid;
  }

  Future<void> requestDeleteChat(String chatId) async {
    final uid = _deleteUid;
    DebugConfig.log(DebugConfig.chatStream, 'requestDeleteChat: chat=$chatId uid=$uid');

    final chatSnap = await firestore.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;
    final chatData = chatSnap.data()!;

    if (chatData['isGroupChat'] == true) {
      DebugConfig.log(DebugConfig.chatStream, 'requestDeleteChat: isGroup → deleteGroup');
      await deleteGroup(chatId);
      return;
    }

    final participants = List<String>.from(chatData['participants'] ?? []);
    final activeMap = Map<String, dynamic>.from(chatData['participantIsActive'] as Map? ?? {});
    final otherActive = participants.where((p) => p != uid && activeMap[p] != false).toList();

    if (otherActive.isEmpty) {
      DebugConfig.log(DebugConfig.chatStream, 'requestDeleteChat: no active other participant, deleting immediately');
      await _deleteChatForEveryone(chatId);
      return;
    }

    await _sendDeleteSystemMessage(chatId, 'delete_request', uid);
    DebugConfig.log(DebugConfig.repositoryResult, 'requestDeleteChat: done chat=$chatId');
  }

  Future<void> approveDeleteChat(String chatId) async {
    final uid = _deleteUid;
    DebugConfig.log(DebugConfig.chatStream, 'approveDeleteChat: chat=$chatId uid=$uid');
    await _sendDeleteSystemMessage(chatId, 'delete_approved', uid);
    await _deleteChatForEveryone(chatId);
  }

  Future<void> rejectDeleteChat(String chatId) async {
    final uid = _deleteUid;
    DebugConfig.log(DebugConfig.chatStream, 'rejectDeleteChat: chat=$chatId uid=$uid');

    await _sendDeleteSystemMessage(chatId, 'delete_rejected', uid);
    DebugConfig.log(DebugConfig.repositoryResult, 'rejectDeleteChat: done chat=$chatId');
  }

  Future<void> cancelDeleteRequest(String chatId) async {
    final uid = _deleteUid;
    DebugConfig.log(DebugConfig.chatStream, 'cancelDeleteRequest: chat=$chatId uid=$uid');

    await _sendDeleteSystemMessage(chatId, 'delete_cancelled', uid);
    DebugConfig.log(DebugConfig.repositoryResult, 'cancelDeleteRequest: done chat=$chatId');
  }

  Future<void> deleteChatForMe(String chatId) async {
    final uid = _deleteUid;
    DebugConfig.log(DebugConfig.chatStream, 'deleteChatForMe: chat=$chatId uid=$uid');

    await _sendDeleteSystemMessage(chatId, 'delete_local', uid);

    await firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([uid]),
    });

    await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
    await EncryptionUtils.deleteKey(chatId);
    messageEncryptCache.remove(chatId);
    messageDecryptCache.remove(chatId);

    DebugConfig.log(DebugConfig.repositoryResult, 'deleteChatForMe: done chat=$chatId');
  }

  Future<void> _deleteChatForEveryone(String chatId) async {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('delete_chat', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    final uid = user.uid;

    DebugConfig.log(DebugConfig.repositoryCall, '_deleteChatForEveryone: deleting chat=$chatId uid=$uid');

    try {
      DebugConfig.log(DebugConfig.repositoryCall, '_deleteChatForEveryone: deleting messages for chat=$chatId');

      const batchSize = 500;
      int totalDeleted = 0;
      bool hasMore = true;

      while (hasMore) {
        final messages = await firestore
            .collection('chats').doc(chatId).collection('messages')
            .limit(batchSize)
            .get();

        if (messages.docs.isEmpty) break;

        final batch = firestore.batch();
        for (final doc in messages.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        totalDeleted += messages.docs.length;
        DebugConfig.log(DebugConfig.firestoreWrite,
            '_deleteChatForEveryone: batch deleted ${messages.docs.length} '
            '(total=$totalDeleted) chat=$chatId');

        if (messages.docs.length < batchSize) hasMore = false;
      }
      DebugConfig.log(DebugConfig.firestoreWrite, '_deleteChatForEveryone: messages phase done chat=$chatId totalDeleted=$totalDeleted');

      try {
        await firestore.collection('chats').doc(chatId).delete();
        DebugConfig.log(DebugConfig.firestoreWrite, '_deleteChatForEveryone: chat document deleted OK chat=$chatId');
      } catch (e) {
        DebugConfig.error('_deleteChatForEveryone: chat doc delete failed', data: e);
        rethrow;
      }

      await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      await EncryptionUtils.deleteKey(chatId);
      messageEncryptCache.remove(chatId);
      messageDecryptCache.remove(chatId);

      DebugConfig.log(DebugConfig.repositoryResult, '_deleteChatForEveryone: done chat=$chatId');
    } catch (e) {
      DebugConfig.warn('_deleteChatForEveryone failed, cleaning local cache', data: e);
      await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      await EncryptionUtils.deleteKey(chatId);
      messageEncryptCache.remove(chatId);
      messageDecryptCache.remove(chatId);
      throw AppException.firestore('delete_chat', 'Αποτυχία διαγραφής συνομιλίας / Failed to delete chat');
    }
  }

  Future<void> _sendDeleteSystemMessage(String chatId, String action, String actorUid) async {
    if (actorUid.isEmpty) return;

    final chatSnap = await firestore.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;
    final chatData = chatSnap.data()!;
    final nicknames = chatData['participantNicknames'] as Map<String, dynamic>? ?? {};
    final actorNickname = nicknames[actorUid] as String? ?? actorUid;

    final formatted = SystemMessageFormatter.format(
      action: action,
      actorNickname: actorNickname,
    );

    await firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': actorUid,
      'type': 'system',
      'action': action,
      'content': formatted.el,
      'contentEn': formatted.en,
      'timestamp': FieldValue.serverTimestamp(),
    });

    DebugConfig.log(DebugConfig.chatStream,
        '_sendDeleteSystemMessage: chat=$chatId action=$action actor=$actorNickname');
  }
}
