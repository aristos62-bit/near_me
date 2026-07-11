import 'package:cached_network_image/cached_network_image.dart';
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

class PermissionsEditorScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String targetUid;
  const PermissionsEditorScreen({
    super.key,
    required this.chatId,
    required this.targetUid,
  });

  @override
  ConsumerState<PermissionsEditorScreen> createState() =>
      _PermissionsEditorScreenState();
}

class _PermissionsEditorScreenState
    extends ConsumerState<PermissionsEditorScreen> {
  final Set<String> _savingPermissions = {};

  static const _basicPermissions = [
    GroupPermission.inviteMembers,
    GroupPermission.removeMembers,
    GroupPermission.deleteMessages,
    GroupPermission.changeGroupName,
    GroupPermission.changeGroupAvatar,
  ];

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction,
        'PermissionsEditorScreen init: chat=${widget.chatId}, target=${widget.targetUid}');
  }

  @override
  void dispose() {
    DebugConfig.log(DebugConfig.uiInteraction,
        'PermissionsEditorScreen dispose: chat=${widget.chatId}');
    super.dispose();
  }

  bool _roleDefaultFor(String role, GroupPermission p) {
    if (role == 'creator') return true;
    if (role == 'admin') {
      return p != GroupPermission.manageAdmins &&
          p != GroupPermission.managePermissions;
    }
    return false;
  }

  String _permissionLabel(GroupPermission p) {
    final greek = L10n.isGreek(context);
    switch (p) {
      case GroupPermission.inviteMembers:
        return greek ? 'Πρόσκληση μελών' : 'Invite members';
      case GroupPermission.removeMembers:
        return greek ? 'Αφαίρεση μελών' : 'Remove members';
      case GroupPermission.deleteMessages:
        return greek ? 'Διαγραφή μηνυμάτων' : 'Delete messages';
      case GroupPermission.changeGroupName:
        return greek ? 'Αλλαγή ονόματος' : 'Change group name';
      case GroupPermission.changeGroupAvatar:
        return greek ? 'Αλλαγή εικόνας' : 'Change group avatar';
      case GroupPermission.managePermissions:
        return greek ? 'Διαχείριση δικαιωμάτων' : 'Manage permissions';
      case GroupPermission.manageAdmins:
        return greek ? 'Διαχείριση διαχειριστών' : 'Manage admins';
      case GroupPermission.pinMessages:
        return greek ? 'Καρφίτσωμα μηνυμάτων' : 'Pin messages';
    }
  }

  String _permissionSubtitle(GroupPermission p, String role, bool hasOverride) {
    final greek = L10n.isGreek(context);
    final defaultValue = _roleDefaultFor(role, p);
    if (hasOverride) {
      return greek
          ? 'Παράκαμψη — προεπιλογή: ${defaultValue ? "Ναι" : "Όχι"}'
          : 'Override — default: ${defaultValue ? "Yes" : "No"}';
    }
    return greek ? 'Προεπιλογή ρόλου' : 'Role default';
  }

  String _nicknameFor(Map<String, dynamic>? chatData) {
    final nicknames = chatData?['participantNicknames'] as Map<String, dynamic>?;
    if (nicknames?.containsKey(widget.targetUid) == true) {
      return nicknames![widget.targetUid] as String;
    }
    final uid = widget.targetUid;
    return uid.length > 12 ? '${uid.substring(0, 12)}...' : uid;
  }

  String _roleLabel(String role) {
    final greek = L10n.isGreek(context);
    switch (role) {
      case 'creator':
        return greek ? 'Δημιουργός' : 'Creator';
      case 'admin':
        return greek ? 'Διαχειριστής' : 'Admin';
      default:
        return greek ? 'Μέλος' : 'Member';
    }
  }

  Future<void> _togglePermission(
      GroupPermission p, bool newValue, String role) async {
    if (_savingPermissions.contains(p.name)) return;
    setState(() => _savingPermissions.add(p.name));
    try {
      final ok = await ref
          .read(chatActionsProvider.notifier)
          .updatePermissionOverride(widget.chatId, widget.targetUid, p, newValue);
      if (!mounted) return;
      if (ok) {
        AppMessenger.showSuccess(
            context,
            L10n.isGreek(context)
                ? 'Το δικαίωμα ενημερώθηκε'
                : 'Permission updated');
      } else {
        AppMessenger.showError(
            context,
            L10n.isGreek(context)
                ? 'Αποτυχία ενημέρωσης δικαιώματος'
                : 'Failed to update permission');
      }
    } finally {
      if (mounted) setState(() => _savingPermissions.remove(p.name));
    }
  }

  Future<void> _resetOverrides() async {
    final greek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(
          context, 'Επαναφορά δικαιωμάτων / Reset permissions'),
      message: L10n.localizedMessage(context,
          'Θα αφαιρεθούν όλες οι παρακάμψεις δικαιωμάτων. Συνέχεια; / All permission overrides will be removed. Continue?'),
      confirmLabel: greek ? 'Επαναφορά' : 'Reset',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(chatActionsProvider.notifier)
        .deletePermissionOverrides(widget.chatId, widget.targetUid);
    if (!mounted) return;
    if (ok) {
      AppMessenger.showSuccess(
          context,
          greek
              ? 'Τα δικαιώματα επαναφέρθηκαν'
              : 'Permissions reset to defaults');
    } else {
      AppMessenger.showError(
          context,
          greek
              ? 'Αποτυχία επαναφοράς'
              : 'Failed to reset permissions');
    }
  }

  Future<void> _changeRole(String newRole) async {
    final greek = L10n.isGreek(context);
    final isPromote = newRole == 'admin';
    final chatData = ref.read(chatDocProvider(widget.chatId)).asData?.value?.data() as Map<String, dynamic>?;
    final nick = _nicknameFor(chatData);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(
          context,
          isPromote
              ? 'Προαγωγή σε Admin / Promote to Admin'
              : 'Υποβιβασμός σε Μέλος / Demote to Member'),
      message: L10n.localizedMessage(context,
          isPromote
              ? 'Θα προαχθεί ο/η $nick σε Admin. Συνέχεια;'
              : 'Θα αφαιρεθούν τα δικαιώματα Admin από τον/την $nick. Συνέχεια;'),
      confirmLabel: greek ? (isPromote ? 'Προαγωγή' : 'Υποβιβασμός') : (isPromote ? 'Promote' : 'Demote'),
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: !isPromote,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(chatActionsProvider.notifier).updateParticipantRole(
            widget.chatId,
            widget.targetUid,
            newRole,
          );
      if (!mounted) return;
      AppMessenger.showSuccess(
          context,
          greek
              ? 'Ο ρόλος ενημερώθηκε'
              : 'Role updated');
    } catch (e, s) {
      DebugConfig.error('PermissionsEditor: role change failed', data: e, exception: s);
      if (!mounted) return;
      AppMessenger.showError(
          context,
          greek
              ? 'Αποτυχία αλλαγής ρόλου'
              : 'Failed to change role');
    }
  }

  Future<void> _removeMember() async {
    final greek = L10n.isGreek(context);
    final chatData = ref.read(chatDocProvider(widget.chatId)).asData?.value?.data() as Map<String, dynamic>?;
    final nick = _nicknameFor(chatData);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(
          context, 'Αφαίρεση μέλους / Remove member'),
      message: L10n.localizedMessage(context,
          'Θα αφαιρεθεί ο/η $nick από την ομάδα. Συνέχεια;'),
      confirmLabel: greek ? 'Αφαίρεση' : 'Remove',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(chatActionsProvider.notifier).removeParticipant(
            widget.chatId,
            widget.targetUid,
          );
      if (!mounted) return;
      AppMessenger.showSuccess(
          context,
          greek
              ? 'Το μέλος αφαιρέθηκε'
              : 'Member removed');
      context.pop();
    } catch (e, s) {
      DebugConfig.error('PermissionsEditor: remove failed', data: e, exception: s);
      if (!mounted) return;
      AppMessenger.showError(
          context,
          greek
              ? 'Αποτυχία αφαίρεσης'
              : 'Failed to remove member');
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final chatDocAsync = ref.watch(chatDocProvider(widget.chatId));
    final chatData = chatDocAsync.asData?.value?.data() as Map<String, dynamic>?;
    final permsAsync = ref.watch(groupPermissionsProvider(widget.chatId));

    final roles = chatData?['participantRoles'] as Map<String, dynamic>?;
    final participantRole = roles?[widget.targetUid] as String?;
    final isTargetActive = participantRole != null;
    final isCreator = currentUid == chatData?['createdBy'];
    final canManage = isCreator;

    ref.listen(chatDocProvider(widget.chatId), (prev, next) {
      if (!mounted) return;
      setState(() {});
    });

    final isLoading = chatDocAsync.isLoading || permsAsync.isLoading;
    final hasError = chatDocAsync.hasError || permsAsync.hasError;
    final permsInfo = permsAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTargetActive ? _nicknameFor(chatData) : widget.targetUid),
      ),
      body: isLoading
          ? const LoadingView()
          : hasError || permsInfo == null || !isTargetActive
              ? _buildErrorView(greek)
              : _buildContent(
                  greek, theme, permsInfo, participantRole, canManage, chatData),
    );
  }

  Widget _buildErrorView(bool greek) {
    if (!mounted) return const SizedBox.shrink();
    final data = ref.read(chatDocProvider(widget.chatId)).asData?.value?.data()
        as Map<String, dynamic>?;
    final roles = (data?['participantRoles'] as Map<String, dynamic>?) ?? {};
    final isTargetGone = !roles.containsKey(widget.targetUid);
    if (isTargetGone) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                greek
                    ? 'Το μέλος δεν ανήκει πλέον στην ομάδα'
                    : 'Member is no longer in this group',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: Text(greek ? 'Επιστροφή' : 'Go back'),
              ),
            ],
          ),
        ),
      );
    }
    return ErrorView(
      message: greek ? 'Σφάλμα φόρτωσης' : 'Failed to load',
      onRetry: () {
        ref.invalidate(groupPermissionsProvider(widget.chatId));
      },
    );
  }

  Widget _buildContent(bool greek, ThemeData theme,
      GroupPermissionsInfo permsInfo, String role, bool canManage, Map<String, dynamic>? chatData) {
    final targetOverrides = permsInfo.overrides[widget.targetUid] ?? {};

    return ListView(
      padding: EdgeInsets.all(
        ResponsiveUtils.paddingValueFromWidth(
            ResponsiveUtils.resolveWidth(context, null)),
      ),
      children: [
        _buildHeader(greek, theme, role, chatData),
        const SizedBox(height: 16),
        _buildSectionHeader(greek, theme, 'Basics',
            greek ? 'Βασικά δικαιώματα' : 'Basic permissions'),
        ..._basicPermissions.map((p) => _buildPermissionTile(
              greek, theme, p, role, permsInfo, targetOverrides, canManage,
            )),
        const SizedBox(height: 16),
        _buildSectionHeader(greek, theme, 'For Admins',
            greek ? 'Για Διαχειριστές' : 'For Admins'),
        _buildPermissionTile(greek, theme, GroupPermission.pinMessages, role,
            permsInfo, targetOverrides, canManage),
        const SizedBox(height: 24),
        if (canManage) _buildManagementSection(greek, theme, role),
        const SizedBox(height: 12),
        _buildResetButton(greek),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader(bool greek, ThemeData theme, String role, Map<String, dynamic>? chatData) {
    final nick = _nicknameFor(chatData);
    final avatarUrl = (chatData?['participantAvatarUrls'] as Map<String, dynamic>?)?[widget.targetUid] as String?;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: role == 'creator'
              ? theme.colorScheme.tertiaryContainer
              : role == 'admin'
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(nick.isNotEmpty ? nick[0].toUpperCase() : '?')
              : null,
        ),
        title: Text(nick,
            style: theme.textTheme.titleMedium),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: role == 'creator'
                    ? theme.colorScheme.tertiaryContainer
                    : role == 'admin'
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _roleLabel(role),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: role == 'creator'
                      ? theme.colorScheme.onTertiaryContainer
                      : role == 'admin'
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      bool greek, ThemeData theme, String en, String gr) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        greek ? gr : en,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    bool greek,
    ThemeData theme,
    GroupPermission p,
    String role,
    GroupPermissionsInfo permsInfo,
    Map<String, bool> targetOverrides,
    bool canManage,
  ) {
    final effectiveValue = permsInfo.hasPermission(widget.targetUid, p);
    final hasOverride = targetOverrides.containsKey(p.name);
    final isSaving = _savingPermissions.contains(p.name);

    return Opacity(
      opacity: isSaving ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: SwitchListTile(
          title: Text(_permissionLabel(p)),
          subtitle: Text(
            _permissionSubtitle(p, role, hasOverride),
            style: theme.textTheme.bodySmall?.copyWith(
              color: hasOverride
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value: effectiveValue,
          onChanged: canManage && !isSaving
              ? (v) => _togglePermission(p, v, role)
              : null,
          secondary: isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  hasOverride ? Icons.tune : Icons.lock_outline,
                  size: 20,
                  color: hasOverride
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }

  Widget _buildManagementSection(
      bool greek, ThemeData theme, String role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(greek, theme, 'Management (Creator only)',
            greek ? 'Διαχείριση (μόνο Δημιουργός)' : 'Management (Creator only)'),
        const SizedBox(height: 8),
        if (role == 'member')
          FilledButton.icon(
            onPressed: () => _changeRole('admin'),
            icon: const Icon(Icons.star, size: 18),
            label: Text(greek ? 'Προαγωγή σε Admin' : 'Promote to Admin'),
          ),
        if (role == 'admin')
          OutlinedButton.icon(
            onPressed: () => _changeRole('member'),
            icon: const Icon(Icons.arrow_downward, size: 18),
            label: Text(greek ? 'Υποβιβασμός σε Μέλος' : 'Demote to Member'),
          ),
        if (role != 'creator') ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _removeMember,
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: Text(greek ? 'Αφαίρεση από ομάδα' : 'Remove from group'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResetButton(bool greek) {
    return OutlinedButton.icon(
      onPressed: _resetOverrides,
      icon: const Icon(Icons.restart_alt, size: 18),
      label: Text(greek
          ? 'Επαναφορά στην προεπιλογή ρόλου'
          : 'Reset to role default'),
    );
  }
}
