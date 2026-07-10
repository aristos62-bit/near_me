import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
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
        data: (invites) => _InvitesList(chatId: chatId, invites: invites),
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
                AppMessenger.showError(ctx,
                    greek ? 'Οι ημέρες πρέπει να είναι 1-365' : 'Days must be 1-365');
                return;
              }
              if (uses == null || uses < 1 || uses > 1000) {
                AppMessenger.showError(ctx,
                    greek ? 'Οι χρήσεις πρέπει να είναι 1-1000' : 'Uses must be 1-1000');
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
    if (token != null && context.mounted) {
      await Clipboard.setData(ClipboardData(text: token));
      if (context.mounted) {
        AppMessenger.showSuccess(context, greek
            ? 'Το invite token αντιγράφηκε στο clipboard'
            : 'Invite token copied to clipboard');
      }
    }
  }
}

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
                      Clipboard.setData(ClipboardData(text: invite.token));
                      AppMessenger.showSuccess(context, greek
                          ? 'Αντιγράφηκε' : 'Copied');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(greek ? 'Αντιγραφή' : 'Copy'),
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
