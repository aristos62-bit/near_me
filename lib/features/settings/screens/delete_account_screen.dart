import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/delete_account_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _confirmCtrl.addListener(() {
      final match = _confirmCtrl.text.trim().toUpperCase() == 'DELETE';
      if (match != _confirmed) {
        DebugConfig.log(DebugConfig.uiInteraction, 'delete confirm: $match');
        setState(() => _confirmed = match);
      }
    });
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showReauthDialog(String? email) {
    _passwordCtrl.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final greek = L10n.isGreek(context);
        return AlertDialog(
          title: Text(L10n.localizedMessage(context, 'Επιβεβαίωση ταυτότητας / Confirm identity')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(L10n.localizedMessage(context, 'Για λόγους ασφαλείας, πληκτρολόγησε ξανά τον κωδικό σου. / For security, please re-enter your password.')),
              if (email != null) ...[
                const SizedBox(height: 8),
                Text(email, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: greek ? 'Κωδικός' : 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(deleteAccountProvider.notifier).reset();
              },
              child: Text(greek ? 'Ακύρωση' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (_passwordCtrl.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop();
                  ref.read(deleteAccountProvider.notifier).deleteWithPassword(_passwordCtrl.text.trim());
                }
              },
              child: Text(greek ? 'Επιβεβαίωση' : 'Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountProvider);
    final theme = Theme.of(context);
    final greek = L10n.isGreek(context);
    final isWide = ResponsiveUtils.isTablet(context);
    final isAnonymous = ref.watch(authStateProvider).value?.isAnonymous ?? true;

    if (isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: Text(greek ? 'Διαγραφή Λογαριασμού' : 'Delete Account')),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 72,
                            color: theme.colorScheme.primary.withAlpha(80)),
                        const SizedBox(height: 20),
                        Text(
                          greek ? 'Ο λογαριασμός είναι προσωρινός' : 'Account is temporary',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          greek
                              ? 'Για να διαγράψεις τον λογαριασμό σου, πρέπει πρώτα να τον επαληθεύσεις με email.'
                              : 'To delete your account, you need to verify it with an email first.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => context.push('/auth'),
                          icon: const Icon(Icons.verified_user_outlined, size: 18),
                          label: Text(greek ? 'Επαλήθευση Λογαριασμού' : 'Verify Account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    ref.listen<DeleteAccountState>(deleteAccountProvider, (_, next) {
      if (next.status == DeleteState.success) {
        AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Ο λογαριασμός διαγράφηκε / Account deleted'));
        context.go('/auth');
      } else if (next.status == DeleteState.error) {
        AppMessenger.showError(context, ErrorMessages.get(next.errorMessage ?? 'delete/unknown-error', L10n.isGreek(context)));
      } else if (next.status == DeleteState.needsReauth) {
        _showReauthDialog(next.email);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(greek ? 'Διαγραφή Λογαριασμού' : 'Delete Account')),
      body: state.status == DeleteState.loading
          ? const LoadingView()
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 600 : 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GradientHeader(
                        gradientColors: [AppColors.error, AppColors.error.withAlpha(200)],
                        icon: Icons.warning_rounded,
                        title: greek ? 'Διαγραφή Λογαριασμού' : 'Delete Account',
                        subtitle: greek ? 'Αυτή η ενέργεια είναι μη αναστρέψιμη' : 'This action cannot be undone',
                      ),
                      const SizedBox(height: 20),
                      _buildWarningCard(theme, greek),
                      const SizedBox(height: 16),
                      _buildConfirmationCard(theme, greek),
                      const SizedBox(height: 24),
                      _buildDeleteButton(theme, greek),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWarningCard(ThemeData theme, bool greek) {
    return FormSection(
      icon: Icons.delete_outline,
      title: greek ? 'Δεδομένα που θα διαγραφούν' : 'Data that will be deleted',
      children: [
        _deleteItem(theme, Icons.cloud_off, greek ? 'Δημόσιο προφίλ (Firestore)' : 'Public profile (Firestore)'),
        _deleteItem(theme, Icons.photo_library_outlined, greek ? 'Φωτογραφίες (Storage)' : 'Photos (Storage)'),
        _deleteItem(theme, Icons.send_outlined, greek ? 'Αιτήματα γνωριμίας / Requests' : 'Connection requests'),
        _deleteItem(theme, Icons.chat_bubble_outline, greek ? 'Μηνύματα συνομιλιών (απόκρυψη)' : 'Chat messages (anonymized)'),
        _deleteItem(theme, Icons.storage, greek ? 'Τοπικά δεδομένα (Isar)' : 'Local data (Isar)'),
        _deleteItem(theme, Icons.person_off, greek ? 'Λογαριασμός (Firebase Auth)' : 'Account (Firebase Auth)'),
      ],
    );
  }

  Widget _deleteItem(ThemeData theme, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildConfirmationCard(ThemeData theme, bool greek) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greek ? 'Επιβεβαίωση' : 'Confirmation',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              greek ? 'Πληκτρολόγησε DELETE για επιβεβαίωση:' : 'Type DELETE to confirm:',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                hintText: greek ? 'πληκτρολόγησε DELETE' : 'type DELETE',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _confirmed ? AppColors.error : theme.colorScheme.primary),
                ),
              ),
              style: TextStyle(
                color: _confirmed ? AppColors.error : null,
                fontWeight: _confirmed ? FontWeight.bold : null,
              ),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(ThemeData theme, bool greek) {
    return FilledButton.icon(
      onPressed: _confirmed
          ? () async {
              DebugConfig.log(DebugConfig.uiInteraction, 'Delete account button tapped');
              final proceed = await AppMessenger.showConfirmDialog(
                context,
                title: L10n.localizedMessage(context, 'Οριστική διαγραφή; / Permanent deletion?'),
                message: L10n.localizedMessage(context, 'Όλα τα δεδομένα σου θα χαθούν. Συνέχεια; / All your data will be lost. Continue?'),
                confirmLabel: greek ? 'Διαγραφή' : 'Delete',
                cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
                isDestructive: true,
              );
              if (proceed && mounted) {
                ref.read(deleteAccountProvider.notifier).delete();
              }
            }
          : null,
      icon: const Icon(Icons.delete_forever, size: 20),
      label: Text(greek ? 'Διαγραφή Λογαριασμού' : 'Delete Account'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.error,
        disabledBackgroundColor: theme.colorScheme.onSurface.withAlpha(30),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
