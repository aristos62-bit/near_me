import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
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
  Map<String, dynamic>? _participantNicknames;
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
        _participantNicknames = data['participantNicknames'] as Map<String, dynamic>?;
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

  String _nicknameFor(String uid) {
    if (_participantNicknames?.containsKey(uid) == true) {
      return _participantNicknames![uid] as String? ?? uid;
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
      await ref.read(chatActionsProvider.notifier).removeParticipant(widget.chatId, uid);
    }
  }

  Future<void> _leaveGroup() async {
    final greek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Αποχώρηση / Leave group'),
      message: L10n.localizedMessage(context,
          'Θα αποχωρήσεις από την ομάδα. Συνέχεια; / You will leave the group. Continue?'),
      confirmLabel: greek ? 'Αποχώρηση' : 'Leave',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      await ref.read(chatActionsProvider.notifier).removeParticipant(widget.chatId, uid);
      if (!mounted) return;
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final chatDocAsync = ref.watch(chatDocProvider(widget.chatId));
    final participantUidsAsync = ref.watch(participantUidsProvider(widget.chatId));
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';

    ref.listen(chatDocProvider(widget.chatId), (prev, next) {
      if (mounted) _onDocChanged(next.asData?.value);
      if (next.hasError && mounted) {
        DebugConfig.error('GroupInfoScreen: chatDoc error', data: next.error);
      }
    });
    final participantUids = participantUidsAsync.asData?.value ?? <String>[];
    final isCreator = currentUid == _createdBy;
    final myRole = _participantRoles?[currentUid] as String?;
    final isAdmin = isCreator || (myRole == 'admin');

    return Scaffold(
      appBar: AppBar(title: Text(_groupName ?? widget.chatId)),
      body: chatDocAsync.isLoading
          ? const LoadingView()
          : ListView(
              padding: EdgeInsets.all(ResponsiveUtils.paddingValueFromWidth(
                  ResponsiveUtils.resolveWidth(context, null))),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.group)),
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
                              Expanded(child: Text(_groupName ?? widget.chatId,
                                  style: theme.textTheme.titleMedium)),
                              if (isAdmin) const Icon(Icons.edit, size: 16),
                            ]),
                          ),
                    subtitle: Text(greek
                        ? '$_maxParticipants max μέλη'
                        : '$_maxParticipants max members'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(greek ? 'Μέλη (${participantUids.length})' : 'Members (${participantUids.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                ...participantUids.map((uid) {
                  final role = _participantRoles?[uid] as String? ?? 'member';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'creator'
                            ? theme.colorScheme.tertiaryContainer
                            : role == 'admin'
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                        child: Text(_nicknameFor(uid)[0].toUpperCase()),
                      ),
                      title: Text(_nicknameFor(uid)),
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
                                  const PopupMenuItem(value: 'permissions', child: Text('Permissions')),
                                if (role != 'admin' && role != 'creator')
                                  const PopupMenuItem(value: 'make_admin', child: Text('Make admin')),
                                if (role == 'admin')
                                  const PopupMenuItem(value: 'make_member', child: Text('Remove admin')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'remove', child: Text('Remove')),
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
                        'currentParticipantUids': _participantRoles?.keys.toList() ?? [],
                        'maxParticipants': _maxParticipants,
                      },
                    ),
                    icon: const Icon(Icons.person_add),
                    label: Text(greek ? 'Προσθήκη Μέλους' : 'Add Member'),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/groups/${widget.chatId}/invite'),
                  icon: const Icon(Icons.link),
                  label: Text(greek ? 'Διαχείριση Invites' : 'Manage Invites'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/groups/${widget.chatId}/settings'),
                  icon: const Icon(Icons.settings),
                  label: Text(greek ? 'Ρυθμίσεις' : 'Settings'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/groups/${widget.chatId}/audit-log'),
                  icon: const Icon(Icons.history),
                  label: Text(greek ? 'Αρχείο Καταγραφής' : 'Audit Log'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _leaveGroup,
                  icon: const Icon(Icons.exit_to_app),
                  label: Text(greek ? 'Αποχώρηση από ομάδα' : 'Leave group'),
                ),
              ],
            ),
    );
  }
}
