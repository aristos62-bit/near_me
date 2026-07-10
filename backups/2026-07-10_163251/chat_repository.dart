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
  Future<void> sendMessage(String chatId, String content);
  Future<List<ChatCacheTableData>> getChats();
  Stream<List<ChatCacheTableData>> streamChats();
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId);
  Future<void> markAsRead(String chatId);
  Future<void> deleteChat(String chatId);
  Future<void> clearMessages(String chatId);

  // Group chat
  Future<String> createGroupChat(List<String> participantUids, {String? groupName});
  Future<void> addParticipant(String chatId, String newUid);
  Future<void> removeParticipant(String chatId, String uid);
  Future<List<String>> getParticipantUids(String chatId);
  Stream<List<String>> participantUidsStream(String chatId);
  Future<void> updateGroupName(String chatId, String name);
  Future<void> updateParticipantRole(String chatId, String uid, String newRole);
  Future<void> updatePermissionOverride(String chatId, String uid, GroupPermission permission, bool value);
  Future<bool> hasPermission(String chatId, GroupPermission permission);
  Future<GroupPermissionsInfo> getPermissionsInfo(String chatId);

  // Group avatar
  Future<void> updateGroupAvatar(String chatId, dynamic image);
  Future<void> removeGroupAvatar(String chatId);

  // Invite links
  Future<String> createInviteLink(String chatId, {Duration expiresIn = const Duration(days: 7), int? maxUses});
  Future<String?> redeemInviteLink(String token);
  Future<InviteInfo?> getInviteInfo(String token);
  Future<void> revokeInvite(String chatId, String inviteId);
  Future<List<InviteInfo>> getActiveInvites(String chatId);

  // Public group join
  Future<void> joinPublicGroup(String chatId);
}
