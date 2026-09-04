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
      await deleteChatSubcollection(firestore, chatId, 'messages');

      await deleteAllChatMedia(chatId);

      messageEncryptCache.remove(chatId);
      messageDecryptCache.remove(chatId);

      DebugConfig.log(DebugConfig.repositoryResult,
          'clearMessages: done chat=$chatId');
    } catch (e) {
      DebugConfig.error('clearMessages failed', data: e);
      throw AppException.firestore('clear_messages',
          'Αποτυχία διαγραφής μηνυμάτων / Failed to clear messages');
    }
  }
}
