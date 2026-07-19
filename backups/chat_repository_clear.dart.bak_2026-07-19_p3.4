part of 'chat_repository_impl.dart';

mixin ChatClearMixin {
  FirebaseFirestore get firestore;
  FirebaseAuth get auth;
  Map<String, Map<String, String>> get messageEncryptCache;
  Map<String, Map<String, String>> get messageDecryptCache;
  Future<void> _requirePermission(String chatId, GroupPermission permission);

  Future<void> clearMessages(String chatId) async {
    final user = auth.currentUser;
    if (user == null) {
      throw AppException.auth('clear_messages',
          'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    }

    final chatDoc = await firestore.collection('chats').doc(chatId).get();
    if (chatDoc.data()?['isGroupChat'] == true) {
      await _requirePermission(chatId, GroupPermission.deleteMessages);
      DebugConfig.log(DebugConfig.authGuard,
          'clearMessages: group permission OK chat=$chatId');
    }

    DebugConfig.log(DebugConfig.repositoryCall,
        'clearMessages: clearing messages chat=$chatId');

    try {
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
            'clearMessages: batch deleted ${messages.docs.length} '
            '(total=$totalDeleted) chat=$chatId');

        if (messages.docs.length < batchSize) hasMore = false;
      }

      messageEncryptCache.remove(chatId);
      messageDecryptCache.remove(chatId);

      DebugConfig.log(DebugConfig.repositoryResult,
          'clearMessages: done chat=$chatId totalDeleted=$totalDeleted');
    } catch (e) {
      DebugConfig.error('clearMessages failed', data: e);
      throw AppException.firestore('clear_messages',
          'Αποτυχία διαγραφής μηνυμάτων / Failed to clear messages');
    }
  }
}
