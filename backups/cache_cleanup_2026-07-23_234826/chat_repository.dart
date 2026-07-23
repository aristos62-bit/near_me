import 'dart:typed_data';
import '../data/local/database.dart';

// ── Group Chat Types ─────────────────────────────────────────

enum GroupPermission {
  inviteMembers,
  removeMembers,
  deleteMessages,
  changeGroupName,
  changeGroupAvatar,
  managePermissions,
  manageAdmins,
  pinMessages,
}

class GroupPermissionsInfo {
  final Map<String, String> roles;
  final Map<String, Map<String, bool>> overrides;

  const GroupPermissionsInfo({
    required this.roles,
    required this.overrides,
  });

  bool hasPermission(String uid, GroupPermission p) {
    final role = roles[uid] ?? 'member';
    final userOverrides = overrides[uid];
    if (userOverrides != null && userOverrides.containsKey(p.name)) {
      return userOverrides[p.name]!;
    }
    if (role == 'creator') return true;
    if (role == 'admin') {
      return p != GroupPermission.manageAdmins
          && p != GroupPermission.managePermissions;
    }
    return false;
  }
}

class InviteInfo {
  final String inviteId;
  final String token;
  final String createdBy;
  final DateTime? expiresAt;
  final int? maxUses;
  final int useCount;
  final bool isRevoked;
  final DateTime createdAt;
  final String? groupName;
  final int? memberCount;

  const InviteInfo({
    required this.inviteId,
    required this.token,
    required this.createdBy,
    this.expiresAt,
    this.maxUses,
    this.useCount = 0,
    this.isRevoked = false,
    required this.createdAt,
    this.groupName,
    this.memberCount,
  });
}

// ── ChatRepository Interface ─────────────────────────────────

abstract class ChatRepository {
  // 1-to-1 (unchanged)
  Future<String> createChat(String otherUid);
  Future<void> sendMessage(String chatId, String content, {Map<String, dynamic>? replyTo});
  Future<List<ChatCacheTableData>> getChats();
  Stream<List<ChatCacheTableData>> streamChats();
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId);
  // Pagination: φέρνει παλιότερα μηνύματα (πριν το beforeTimestamp), one-shot read.
  Future<List<Map<String, dynamic>>> fetchOlderMessages(String chatId,
      {required DateTime beforeTimestamp, int limit = 50});
  Future<void> markAsRead(String chatId, {bool isGroupChat = false});
  Future<void> deleteChat(String chatId);
  Future<void> approveDeleteChat(String chatId);
  Future<void> rejectDeleteChat(String chatId);
  Future<void> cancelDeleteRequest(String chatId);
  Future<void> deleteChatForMe(String chatId);
  Future<void> deleteGroup(String chatId);
  Future<void> clearMessages(String chatId);

  // Group chat
  Future<String> createGroupChat(List<String> participantUids, {String? groupName, bool isPublic = false, String? description, List<String>? tags, String? city});
  Future<void> addParticipant(String chatId, String newUid);
  Future<void> removeParticipant(String chatId, String uid);
  Future<List<String>> getParticipantUids(String chatId);
  Stream<List<String>> participantUidsStream(String chatId);
  Future<void> updateGroupName(String chatId, String name);
  Future<void> updateParticipantRole(String chatId, String uid, String newRole);
  Future<void> updatePermissionOverride(String chatId, String uid, GroupPermission permission, bool value);
  Future<void> deletePermissionOverrides(String chatId, String targetUid);
  Future<bool> hasPermission(String chatId, GroupPermission permission);
  Future<GroupPermissionsInfo> getPermissionsInfo(String chatId);

  // Group avatar
  Future<void> updateGroupAvatar(String chatId, dynamic image);
  Future<void> removeGroupAvatar(String chatId);

  // Group settings
  Future<void> updateMaxParticipants(String chatId, int newMax);

  // Invite links
  Future<String> createInviteLink(String chatId, {Duration expiresIn = const Duration(days: 7), int? maxUses});
  Future<String?> redeemInviteLink(String token);
  Future<InviteInfo?> getInviteInfo(String token);
  Future<void> revokeInvite(String chatId, String inviteId);
  Future<List<InviteInfo>> getActiveInvites(String chatId);

  // Public group join
  Future<void> joinPublicGroup(String chatId);

  // Media messages
  Future<void> sendMediaMessage(String chatId, {
    required String content,
    required String type,
    Map<String, dynamic>? replyTo,
    Uint8List? imageBytes,
  });

  // Profile sync across chats
  Future<void> syncMyProfileAcrossChats({
    required String nickname,
    String? avatarUrl,
  });

  // Reactions
  Future<void> addReaction(String chatId, String messageId, String emoji);
  Future<void> removeReaction(String chatId, String messageId);

  // Message actions
  Future<void> editMessage(String chatId, String messageId, String newContent);
  Future<void> deleteMessage(String chatId, String messageId);
}
