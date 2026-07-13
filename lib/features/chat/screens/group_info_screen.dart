import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../repositories/chat_repository.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String chatId;
  const GroupInfoScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  String? _groupName;
  Map<String, dynamic>? _participantRoles;
  int? _maxParticipants;
  String? _createdBy;
  bool _isEditingName = false;
  final _nameCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'GroupInfoScreen init: ${widget.chatId}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onDocChanged(DocumentSnapshot? snap) {
    if (snap == null || !snap.exists || !mounted) return;
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;
    final name = data['groupName'] as String?;
    final roles = data['participantRoles'] as Map<String, dynamic>?;
    if (name != _groupName || roles != _participantRoles) {
      setState(() {
        _groupName = name;
        _participantRoles = roles;
        _maxParticipants = data['maxParticipants'] as int? ?? 10;
        _createdBy = data['createdBy'] as String?;
        _nameCtrl.text = name ?? widget.chatId;
      });
    }
  }

  String _roleLabel(String role) {
    final greek = L10n.isGreek(context);
    switch (role) {
      case 'creator': return greek ? 'Δημιουργός' : 'Creator';
      case 'admin': return greek ? 'Διαχειριστής' : 'Admin';
      default: return greek ? 'Μέλος' : 'Member';
    }
  }

  String _nicknameFor(String uid, Map<String, dynamic>? nicknames) {
    if (nicknames?.containsKey(uid) == true) {
      return nicknames![uid] as String? ?? uid;
    }
    return uid.length > 12 ? '${uid.substring(0, 12)}...' : uid;
  }

  Future<void> _saveGroupName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name == _groupName) {
      setState(() => _isEditingName = false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(chatActionsProvider.notifier).updateGroupName(widget.chatId, name);
      if (!mounted) return;
      setState(() {
        _isEditingName = false;
        _isSaving = false;
      });
      AppMessenger.showSuccess(context, L10n.isGreek(context)
          ? 'Το όνομα ενημερώθηκε'
          : 'Name updated');
    } catch (e, s) {
      DebugConfig.error('GroupInfo: rename failed', data: e, exception: s);
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppMessenger.showError(context, L10n.isGreek(context)
          ? 'Αποτυχία ενημέρωσης'
          : 'Failed to update');
    }
  }

  Future<void> _changeRole(String uid, String newRole) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'GroupInfoScreen: changeRole $uid -> $newRole in ${widget.chatId}');
    try {
      await ref.read(chatActionsProvider.notifier).updateParticipantRole(widget.chatId, uid, newRole);
      if (!mounted) return;
      AppMessenger.showSuccess(context, L10n.isGreek(context)
          ? 'Ο ρόλος ενημερώθηκε'
          : 'Role updated');
    } catch (e, s) {
      DebugConfig.error('GroupInfo: role change failed', data: e, exception: s);
      if (!mounted) return;
      AppMessenger.showError(context, L10n.isGreek(context)
          ? 'Αποτυχία αλλαγής ρόλου'
          : 'Failed to change role');
    }
  }

  Future<void> _removeParticipant(String uid) async {
    final greek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Αφαίρεση μέλους / Remove member'),
      message: L10n.localizedMessage(context,
          'Θα αφαιρεθεί το μέλος από την ομάδα. Συνέχεια; / The member will be removed. Continue?'),
      confirmLabel: greek ? 'Αφαίρεση' : 'Remove',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      DebugConfig.log(DebugConfig.uiInteraction, 'GroupInfoScreen: removeParticipant $uid from ${widget.chatId}');
      await ref.read(chatActionsProvider.notifier).removeParticipant(widget.chatId, uid);
    }
  }

  Future<void> _deleteGroup() async {
    final greek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Διαγραφή ομάδας / Delete group'),
      message: L10n.localizedMessage(context,
          'Θα διαγραφεί ΟΛΟΚΛΗΡΗ η ομάδα μαζί με όλα τα μηνύματα. Αυτή η ενέργεια είναι μη αναστρέψιμη. Συνέχεια; / The ENTIRE group and all messages will be permanently deleted. This action cannot be undone. Continue?'),
      confirmLabel: greek ? 'Διαγραφή' : 'Delete',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    DebugConfig.log(DebugConfig.uiInteraction, 'GroupInfoScreen: deleteGroup ${widget.chatId}');
    try {
      await ref.read(chatActionsProvider.notifier).deleteGroup(widget.chatId);
      if (!mounted) return;
      context.pop();
    } catch (e, s) {
      DebugConfig.error('GroupInfo: delete group failed', data: e, exception: s);
      if (!mounted) return;
      AppMessenger.showError(context, greek
          ? 'Αποτυχία διαγραφής ομάδας'
          : 'Failed to delete group');
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final chatDocAsync = ref.watch(chatDocProvider(widget.chatId));
    final chatData = chatDocAsync.asData?.value?.data() as Map<String, dynamic>?;
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';

    ref.listen(chatDocProvider(widget.chatId), (prev, next) {
      if (mounted) _onDocChanged(next.asData?.value);
      if (next.hasError && mounted) {
        DebugConfig.error('GroupInfoScreen: chatDoc error', data: next.error);
      }
    });
    final participantUids = ref.watch(participantUidsProvider(widget.chatId));
    final groupName = chatData?['groupName'] as String? ?? _groupName;
    final groupAvatarUrl = chatData?['groupAvatarUrl'] as String?;
    final createdBy = chatData?['createdBy'] as String? ?? _createdBy;
    final rolesMap = chatData?['participantRoles'] as Map<String, dynamic>? ?? _participantRoles;
    final isCreator = currentUid == createdBy;
    final myRole = rolesMap?[currentUid] as String?;
    final permsAsync = ref.watch(groupPermissionsProvider(widget.chatId));
    final permsInfo = permsAsync.asData?.value;
    final isAdmin = permsInfo?.hasPermission(currentUid, GroupPermission.inviteMembers) ?? false;
    DebugConfig.log(DebugConfig.authGuard,
        'GroupInfoScreen: isCreator=$isCreator myRole=$myRole permsLoaded=${permsAsync.hasValue} isAdmin=$isAdmin');

    return Scaffold(
      appBar: AppBar(title: Text(groupName ?? widget.chatId)),
      body: chatDocAsync.isLoading
          ? const LoadingView()
          : ListView(
              padding: EdgeInsets.all(ResponsiveUtils.paddingValueFromWidth(
                  ResponsiveUtils.resolveWidth(context, null))),
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: groupAvatarUrl != null ? CachedNetworkImageProvider(groupAvatarUrl) : null,
                      child: groupAvatarUrl == null ? const Icon(Icons.group) : null,
                    ),
                    title: _isEditingName
                        ? Row(children: [
                            Expanded(child: TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(isDense: true),
                              autofocus: true,
                            )),
                            if (_isSaving)
                              const SizedBox(width: 8, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              IconButton(
                                icon: const Icon(Icons.check, size: 20),
                                onPressed: _saveGroupName,
                              ),
                          ])
                        : GestureDetector(
                            onTap: isAdmin ? () => setState(() => _isEditingName = true) : null,
                            child: Row(children: [
                              Expanded(child: Text(groupName ?? widget.chatId,
                                  style: theme.textTheme.titleMedium)),
                              if (isAdmin) const Icon(Icons.edit, size: 16),
                            ]),
                          ),
                    subtitle: Text(greek
                        ? '${_maxParticipants ?? '-'} max μέλη'
                        : '${_maxParticipants ?? '-'} max members'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(greek ? 'Μέλη (${participantUids.length})' : 'Members (${participantUids.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                ...participantUids.map((uid) {
                  final role = rolesMap?[uid] as String? ?? 'member';
                  final avatarUrl = (chatData?['participantAvatarUrls']
                      as Map<String, dynamic>?)?[uid] as String?;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'creator'
                            ? theme.colorScheme.tertiaryContainer
                            : role == 'admin'
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(_nicknameFor(uid, chatData?['participantNicknames'] as Map<String, dynamic>?)[0].toUpperCase())
                            : null,
                      ),
                      title: Text(_nicknameFor(uid, chatData?['participantNicknames'] as Map<String, dynamic>?)),
                      subtitle: Text(_roleLabel(role),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      trailing: isAdmin && uid != currentUid
                          ? PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'make_admin') {
                                  _changeRole(uid, 'admin');
                                } else if (v == 'make_member') {
                                  _changeRole(uid, 'member');
                                } else if (v == 'permissions') {
                                  context.push('/groups/${widget.chatId}/permissions/$uid');
                                } else if (v == 'remove') {
                                  _removeParticipant(uid);
                                }
                              },
                              itemBuilder: (_) => [
                                if (isCreator && role != 'creator')
                                  PopupMenuItem(value: 'permissions', child: Text(greek ? 'Δικαιώματα' : 'Permissions')),
                                if (role != 'admin' && role != 'creator')
                                  PopupMenuItem(value: 'make_admin', child: Text(greek ? 'Ορισμός διαχειριστή' : 'Make admin')),
                                if (role == 'admin')
                                  PopupMenuItem(value: 'make_member', child: Text(greek ? 'Αφαίρεση διαχειριστή' : 'Remove admin')),
                                const PopupMenuDivider(),
                                PopupMenuItem(value: 'remove', child: Text(greek ? 'Αφαίρεση' : 'Remove')),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '/groups/${widget.chatId}/add',
                      extra: <String, dynamic>{
                        'currentParticipantUids': rolesMap?.keys.toList() ?? [],
                        'maxParticipants': _maxParticipants,
                      },
                    ),
                    icon: const Icon(Icons.person_add),
                    label: Text(greek ? 'Προσθήκη Μέλους' : 'Add Member'),
                  ),
                ],
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/groups/${widget.chatId}/invite'),
                    icon: const Icon(Icons.link),
                    label: Text(greek ? 'Διαχείριση Invites' : 'Manage Invites'),
                  ),
                ],
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/groups/${widget.chatId}/settings'),
                    icon: const Icon(Icons.settings),
                    label: Text(greek ? 'Ρυθμίσεις' : 'Settings'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/groups/${widget.chatId}/audit-log'),
                  icon: const Icon(Icons.history),
                  label: Text(greek ? 'Αρχείο Καταγραφής' : 'Audit Log'),
                ),
                if (isCreator) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _deleteGroup,
                    icon: const Icon(Icons.delete_forever),
                    label: Text(greek ? 'Διαγραφή ομάδας' : 'Delete group'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
