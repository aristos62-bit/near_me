part of 'chat_repository_impl.dart';

mixin ChatMessageActionsMixin {
  FirebaseFirestore get firestore;
  FirebaseAuth get auth;
  Map<String, Map<String, String>> get messageEncryptCache;
  Map<String, Map<String, String>> get messageDecryptCache;
  Future<void> _requirePermission(String chatId, GroupPermission permission);

  Future<void> editMessage(String chatId, String messageId, String newContent) async {
    final user = auth.currentUser;
    if (user == null) {
      throw AppException.auth('edit_message', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    }
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'editMessage: blocked unverified user');
      throw AppException.auth('edit_message', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'editMessage: chat=$chatId msg=$messageId');

    try {
      final msgDoc = await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .get();

      if (!msgDoc.exists) {
        throw AppException.firestore('edit_message', 'Το μήνυμα δεν βρέθηκε / Message not found');
      }

      final msgData = msgDoc.data()!;
      if (msgData['senderId'] != user.uid) {
        throw AppException.auth('edit_message',
            'Μπορείς να επεξεργαστείς μόνο τα δικά σου μηνύματα / You can only edit your own messages');
      }

      final msgType = msgData['type'] as String? ?? 'text';
      if (msgType != 'text') {
        throw AppException(
          message: 'Δεν μπορείς να επεξεργαστείς αυτό τον τύπο μηνύματος / Cannot edit this message type',
          code: 'validation_error',
        );
      }

      final key = await EncryptionUtils.getKeyOrDerive(chatId);
      final encrypted = EncryptionUtils.encryptMessage(key, newContent);

      await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .update({
        'content': encrypted,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      messageDecryptCache[chatId]?.remove(messageId);
      messageEncryptCache[chatId]?.remove(messageId);

      DebugConfig.log(DebugConfig.repositoryResult, 'editMessage: success chat=$chatId msg=$messageId');
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.error('editMessage failed', data: e);
      throw AppException.firestore('edit_message', 'Αποτυχία επεξεργασίας μηνύματος / Failed to edit message');
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final user = auth.currentUser;
    if (user == null) {
      throw AppException.auth('delete_message', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    }
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'deleteMessage: blocked unverified user');
      throw AppException.auth('delete_message', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'deleteMessage: chat=$chatId msg=$messageId');

    try {
      final msgDoc = await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .get();

      if (!msgDoc.exists) return;

      final msgData = msgDoc.data()!;
      final senderId = msgData['senderId'] as String? ?? '';

      if (senderId != user.uid) {
        final chatDoc = await firestore.collection('chats').doc(chatId).get();
        if (chatDoc.data()?['isGroupChat'] == true) {
          await _requirePermission(chatId, GroupPermission.deleteMessages);
        } else {
          throw AppException.auth('delete_message',
              'Μπορείς να διαγράψεις μόνο τα δικά σου μηνύματα / You can only delete your own messages');
        }
      }

      await firestore
          .collection('chats').doc(chatId)
          .collection('messages').doc(messageId)
          .delete();

      messageDecryptCache[chatId]?.remove(messageId);
      messageEncryptCache[chatId]?.remove(messageId);

      DebugConfig.log(DebugConfig.repositoryResult, 'deleteMessage: success chat=$chatId msg=$messageId');
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.error('deleteMessage failed', data: e);
      throw AppException.firestore('delete_message', 'Αποτυχία διαγραφής μηνύματος / Failed to delete message');
    }
  }
}
