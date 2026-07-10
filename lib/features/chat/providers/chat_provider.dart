import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../../data/local/database.dart';
import '../../../repositories/chat_repository.dart';
import '../../../repositories/chat_repository_impl.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'chatRepositoryProvider created');
  return ChatRepositoryImpl();
});

final chatsProvider = StreamProvider<List<ChatCacheTableData>>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'chatsProvider created (StreamProvider)');
  final chatRepo = ref.watch(chatRepositoryProvider);
  final stream = chatRepo.streamChats();
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'chatsProvider disposed'));
  return stream;
});

final messagesProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'messagesProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'messagesProvider disposed for chat: $chatId'));
  final chatRepo = ref.watch(chatRepositoryProvider);
  final stream = chatRepo.messagesStream(chatId).map((messages) {
    DebugConfig.log(DebugConfig.chatStream, 'messagesProvider emitted ${messages.length} messages for chat=$chatId');
    return messages;
  });
  return stream;
});

final participantUidsProvider = StreamProvider.autoDispose.family<List<String>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'participantUidsProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'participantUidsProvider disposed for chat: $chatId'));
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.participantUidsStream(chatId);
});

final groupPermissionsProvider = FutureProvider.autoDispose.family<GroupPermissionsInfo, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'groupPermissionsProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'groupPermissionsProvider disposed for chat: $chatId'));
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getPermissionsInfo(chatId);
});

enum ChatActionStatus { idle, loading, success, error }

class ChatActionState {
  final ChatActionStatus status;
  final String? errorMessage;
  final String? createdChatId;
  const ChatActionState({
    this.status = ChatActionStatus.idle,
    this.errorMessage,
    this.createdChatId,
  });
}

class ChatActionsNotifier extends Notifier<ChatActionState> {
  @override
  ChatActionState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'ChatActionsNotifier built');
    return const ChatActionState();
  }

  ChatRepository get _chatRepo => ref.read(chatRepositoryProvider);

  Future<String?> createChat(String otherUid) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: createChat with $otherUid');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.createChat(otherUid);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: createChat success chatId=$chatId');
      state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
      ref.invalidate(chatsProvider);
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  Future<bool> sendMessage(String chatId, String content) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: sendMessage chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.sendMessage(chatId, content);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: sendMessage success');
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: sendMessage failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<void> markAsRead(String chatId) async {
    try {
      await _chatRepo.markAsRead(chatId);
    } catch (e) {
      DebugConfig.warn('ChatActions: markAsRead failed', data: e);
    }
  }

  Future<void> deleteChat(String chatId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: deleteChat chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.deleteChat(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) {
      DebugConfig.error('ChatActions: deleteChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
    }
  }

  Future<void> clearMessages(String chatId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: clearMessages chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.clearMessages(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
    } catch (e, s) {
      DebugConfig.error('ChatActions: clearMessages failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    if (error is AppException) {
      if (error.message.contains(' / ')) return error.message;
      return error.code;
    }
    if (error.toString().contains('encryption_key_missing')) {
      return 'chat/encryption-error';
    }
    if (error.toString().contains('firestore_error') || error.toString().contains('Firestore')) {
      return 'chat/network-error';
    }
    DebugConfig.warn('chat _friendlyError unhandled: ${error.toString()}');
    return 'chat/unknown-error';
  }

  void reset() => state = const ChatActionState();

  // --- Group Chat Actions ---

  Future<String?> createGroupChat(List<String> participantUids, {String? groupName}) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: createGroupChat');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.createGroupChat(participantUids, groupName: groupName);
      state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
      ref.invalidate(chatsProvider);
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createGroupChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  Future<bool> addParticipant(String chatId, String newUid) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: addParticipant chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.addParticipant(chatId, newUid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(participantUidsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: addParticipant failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> removeParticipant(String chatId, String targetUid) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: removeParticipant chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.removeParticipant(chatId, targetUid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(participantUidsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: removeParticipant failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updateGroupName(String chatId, String name) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateGroupName chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateGroupName(chatId, name);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateGroupName failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updateGroupAvatar(String chatId, dynamic image) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateGroupAvatar chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateGroupAvatar(chatId, image);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateGroupAvatar failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> removeGroupAvatar(String chatId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: removeGroupAvatar chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.removeGroupAvatar(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: removeGroupAvatar failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updateParticipantRole(String chatId, String uid, String newRole) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateParticipantRole chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateParticipantRole(chatId, uid, newRole);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(groupPermissionsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateParticipantRole failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updatePermissionOverride(String chatId, String uid, GroupPermission permission, bool value) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updatePermissionOverride chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updatePermissionOverride(chatId, uid, permission, value);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(groupPermissionsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updatePermissionOverride failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<String?> createInviteLink(String chatId, {Duration expiresIn = const Duration(days: 7), int? maxUses}) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: createInviteLink chat=$chatId');
    try {
      final token = await _chatRepo.createInviteLink(chatId, expiresIn: expiresIn, maxUses: maxUses);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: createInviteLink success token=$token');
      return token;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createInviteLink failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  Future<String?> redeemInviteLink(String token) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: redeemInviteLink');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.redeemInviteLink(token);
      if (chatId != null) {
        state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
        ref.invalidate(chatsProvider);
      } else {
        state = const ChatActionState(status: ChatActionStatus.success);
      }
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: redeemInviteLink failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  Future<bool> revokeInvite(String chatId, String inviteId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: revokeInvite chat=$chatId');
    try {
      await _chatRepo.revokeInvite(chatId, inviteId);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: revokeInvite failed', data: e, exception: s);
      return false;
    }
  }
}

final chatActionsProvider = NotifierProvider<ChatActionsNotifier, ChatActionState>(
  ChatActionsNotifier.new,
);
