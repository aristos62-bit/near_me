import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../../../repositories/chat_repository.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../providers/chat_provider.dart';

class GroupInviteScreen extends ConsumerWidget {
  final String chatId;
  const GroupInviteScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final invitesAsync = ref.watch(activeInvitesProvider(chatId));

    return Scaffold(
      appBar: AppBar(title: Text(greek ? 'Διαχείριση Invites' : 'Manage Invites')),
      body: invitesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: greek ? 'Αποτυχία φόρτωσης' : 'Failed to load',
          onRetry: () => ref.invalidate(activeInvitesProvider(chatId)),
        ),
        data: (invites) {
          DebugConfig.log(DebugConfig.repositoryResult, 'GroupInviteScreen: ${invites.length} active invites for chatId=$chatId');
          return _InvitesList(chatId: chatId, invites: invites);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_invite',
        onPressed: () => _createInvite(context, ref),
        icon: const Icon(Icons.add),
        label: Text(greek ? 'Δημιουργία' : 'Create'),
      ),
    );
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    final greek = L10n.isGreek(context);
    DebugConfig.log(DebugConfig.uiInteraction, 'GroupInviteScreen: create invite chatId=$chatId');
    final daysCtrl = TextEditingController(text: '7');
    final usesCtrl = TextEditingController(text: '10');
    final result = await showDialog<_CreateResult>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(greek ? 'Δημιουργία Invite Link' : 'Create Invite Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: greek ? 'Ημέρες λήξης' : 'Expires in (days)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usesCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: greek ? 'Μέγιστες χρήσεις' : 'Max uses',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(greek ? 'Ακύρωση' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final days = int.tryParse(daysCtrl.text);
              final uses = int.tryParse(usesCtrl.text);
              final ctx = context;
              if (days == null || days < 1 || days > 365) {
                AppMessenger.showError(ctx, ErrorMessages.get('group/invite-days-invalid', greek));
                return;
              }
              if (uses == null || uses < 1 || uses > 1000) {
                AppMessenger.showError(ctx, ErrorMessages.get('group/invite-uses-invalid', greek));
                return;
              }
              Navigator.pop(context, _CreateResult(days: days, maxUses: uses));
            },
            child: Text(greek ? 'Δημιουργία' : 'Create'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final token = await ref.read(chatActionsProvider.notifier)
        .createInviteLink(chatId, expiresIn: Duration(days: result.days), maxUses: result.maxUses);
    if (token == null || !context.mounted) return;
    final snap = ref.read(chatDocProvider(chatId)).value;
    final groupName = (snap?.data() as Map<String, dynamic>?)?['groupName'] as String?;
    await _showInviteMessage(context, ref, token: token, groupName: groupName);
  }

  Future<void> _showInviteMessage(
    BuildContext context,
    WidgetRef ref, {
    required String token,
    String? groupName,
  }) async {
    final greek = L10n.isGreek(context);
    final message = L10n.inviteInvitationMessage(
      groupName: groupName ?? '',
      token: token,
      isGreek: greek,
    );
    DebugConfig.log(DebugConfig.uiInteraction,
        'GroupInviteScreen: showing invite message dialog (token=${token.length >= 8 ? token.substring(0, 8) : token}...)');
    final action = await showDialog<_InviteAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(greek ? 'Μήνυμα πρόσκλησης' : 'Invitation message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(dialogContext).colorScheme.outlineVariant),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    token,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: greek ? 'Αντιγραφή κωδικού' : 'Copy code',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyToken(dialogContext, token, greek),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              child: SelectionArea(
                child: SelectableText(message, style: const TextStyle(height: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _InviteAction.close),
            child: Text(greek ? 'Κλείσιμο' : 'Close'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _InviteAction.share),
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(greek ? 'Κοινή χρήση…' : 'Share…'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _InviteAction.copy),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(greek ? 'Αντιγραφή' : 'Copy'),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _InviteAction.copy) {
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        AppMessenger.showSuccess(context, ErrorMessages.get('group/invite-token-copied', greek));
      }
    } else if (action == _InviteAction.share) {
      try {
        await SharePlus.instance.share(ShareParams(text: message));
      } catch (e) {
        DebugConfig.error('GroupInviteScreen: share invite failed', data: e);
        if (context.mounted) {
          AppMessenger.showError(context, ErrorMessages.get('chat/share-failed', greek));
        }
      }
    }
  }
}

void _copyToken(BuildContext context, String token, bool greek) {
  Clipboard.setData(ClipboardData(text: token));
  AppMessenger.showSuccess(context,
      L10n.localizedMessage(context, 'Ο κωδικός πρόσκλησης αντιγράφηκε. / Invite code copied.'));
}

enum _InviteAction { copy, share, close }

class _CreateResult {
  final int days;
  final int maxUses;
  const _CreateResult({required this.days, required this.maxUses});
}


class _InvitesList extends ConsumerWidget {
  final String chatId;
  final List<InviteInfo> invites;
  const _InvitesList({required this.chatId, required this.invites});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);

    if (invites.isEmpty) {
      return Center(
        child: Text(
          greek ? 'Δεν υπάρχουν ενεργές προσκλήσεις' : 'No active invites',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(ResponsiveUtils.paddingValueFromWidth(
          ResponsiveUtils.resolveWidth(context, null))),
      children: [
        const SizedBox(height: 8),
        ...invites.map((invite) => _InviteTile(chatId: chatId, invite: invite)),
      ],
    );
  }
}

class _InviteTile extends ConsumerWidget {
  final String chatId;
  final InviteInfo invite;
  const _InviteTile({required this.chatId, required this.invite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = invite.expiresAt != null && now.isAfter(invite.expiresAt!);
    final isFull = invite.maxUses != null && invite.useCount >= invite.maxUses!;
    final isValid = !invite.isRevoked && !isExpired && !isFull;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                isValid ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: isValid ? Colors.green : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${invite.token.substring(0, 12)}...',
                  style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: greek ? 'Αντιγραφή κωδικού' : 'Copy code',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => _copyToken(context, invite.token, greek),
              ),
            ]),
            const SizedBox(height: 8),
            _infoRow(context, greek ? 'Χρήσεις' : 'Uses', '${invite.useCount}/${invite.maxUses ?? '∞'}'),
            if (invite.expiresAt != null)
              _infoRow(context, greek ? 'Λήγει' : 'Expires', _formatDate(invite.expiresAt!, greek)),
            _infoRow(context, greek ? 'Δημιουργήθηκε' : 'Created', _formatDate(invite.createdAt, greek)),
            const SizedBox(height: 8),
            Row(children: [
              if (isValid)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final snap = ref.read(chatDocProvider(chatId)).value;
                      final groupName = (snap?.data() as Map<String, dynamic>?)?['groupName'] as String?;
                      final message = L10n.inviteInvitationMessage(
                        groupName: groupName ?? '',
                        token: invite.token,
                        isGreek: greek,
                      );
                      Clipboard.setData(ClipboardData(text: message));
                      AppMessenger.showSuccess(context, ErrorMessages.get('group/invite-token-copied', greek));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(greek ? 'Αντιγραφή πρόσκλησης' : 'Copy invite'),
                  ),
                ),
              if (isValid) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: invite.isRevoked ? null : () => _revoke(context, ref),
                  icon: const Icon(Icons.block, size: 16),
                  label: Text(invite.isRevoked
                      ? (greek ? 'Ανακλημένο' : 'Revoked')
                      : (greek ? 'Ανάκληση' : 'Revoke')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
      ]),
    );
  }

  String _formatDate(DateTime dt, bool greek) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final greek = L10n.isGreek(context);
    DebugConfig.log(DebugConfig.uiInteraction, 'GroupInviteScreen: revoke invite chatId=$chatId');
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Ανάκληση Invite / Revoke Invite'),
      message: L10n.localizedMessage(context,
          'Η πρόσκληση δεν θα είναι πλέον έγκυρη. Συνέχεια; / The invite will no longer be valid. Continue?'),
      confirmLabel: greek ? 'Ανάκληση' : 'Revoke',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      await ref.read(chatActionsProvider.notifier).revokeInvite(chatId, invite.inviteId);
    }
  }
}
