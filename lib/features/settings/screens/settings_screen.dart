import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/lock_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final isGreek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Αποσύνδεση / Sign Out'),
      message: L10n.localizedMessage(context, 'Θέλεις σίγουρα να αποσυνδεθείς; / Are you sure you want to sign out?'),
      confirmLabel: isGreek ? 'Αποσύνδεση' : 'Sign Out',
      cancelLabel: isGreek ? 'Ακύρωση' : 'Cancel',
      isDestructive: false,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    DebugConfig.log(DebugConfig.authFlow, 'SettingsScreen: sign out');
    try {
      await ref.read(authRepositoryProvider).signOut();
      DebugConfig.log(DebugConfig.authFlow, 'SettingsScreen: signed out');
    } catch (e) {
      DebugConfig.error('SettingsScreen: sign out failed', exception: e);
      if (!context.mounted) return;
      AppMessenger.showError(context,
          L10n.localizedMessage(context, 'Αποτυχία αποσύνδεσης / Sign out failed'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGreek = L10n.isGreek(context);
    final user = ref.watch(authStateProvider).value;
    final isAnonymous = user?.isAnonymous ?? false;
    final phoneVerified = !isAnonymous && user!.phoneNumber != null;
    final appSettingsAsync = ref.watch(appSettingsProvider);
    DebugConfig.log(DebugConfig.uiInteraction, 'SettingsScreen build');

    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
          title: Text(isGreek ? 'Ρυθμίσεις' : 'Settings')),
      body: Center(
        child: SizedBox(
          width: ResponsiveUtils.maxContentWidth(context),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (isAnonymous)
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(isGreek ? 'Επαλήθευση Λογαριασμού' : 'Verify Account'),
                  subtitle: Text(isGreek
                      ? 'Σύνδεσε email για ενεργοποίηση λειτουργιών'
                      : 'Link email to enable features'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/auth'),
                ),
              if (isAnonymous)
                const Divider(),

              if (!isAnonymous && user!.emailVerified) ...[
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: Text(isGreek ? 'Επαλήθευση Τηλεφώνου' : 'Verify Phone'),
                  subtitle: Text(phoneVerified
                      ? (isGreek ? 'Επαληθεύτηκε' : 'Verified')
                      : (isGreek
                          ? 'Επιβεβαίωσε τον αριθμό τηλεφώνου σου'
                          : 'Verify your phone number')),
                  trailing: phoneVerified
                      ? Icon(Icons.check_circle, color: AppColors.online)
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/phone-verify'),
                ),
                const Divider(),
              ],

              // --- Ασφάλεια Συσκευής ---
              if (!isAnonymous)
                _SectionHeader(label: isGreek ? 'Ασφάλεια Συσκευής' : 'Device Security'),
              if (!isAnonymous)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: appSettingsAsync.when(
                    loading: () => const ListTile(
                      leading: Icon(Icons.screen_lock_portrait_outlined),
                      title: Text('...'),
                    ),
                    error: (e, _) => ListTile(
                      leading: const Icon(Icons.screen_lock_portrait_outlined),
                      title: Text(isGreek ? 'Σφάλμα φόρτωσης' : 'Load error'),
                    ),
                    data: (settings) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.screen_lock_portrait_outlined),
                          title: Text(isGreek ? 'Αποτροπή Screenshot' : 'Screenshot Prevention'),
                          subtitle: Text(isGreek
                              ? 'Αποτρέπει τη λήψη screenshot στην εφαρμογή'
                              : 'Prevent screenshots within the app'),
                          value: settings.screenshotPreventionEnabled,
                          onChanged: (v) {
                            DebugConfig.log(DebugConfig.uiInteraction,
                                'SettingsScreen: screenshotPreventionEnabled=$v');
                            ref.read(appSettingsProvider.notifier).setScreenshotPrevention(v);
                            AppMessenger.showInfo(context,
                                v
                                    ? (isGreek ? 'Η προστασία ενεργοποιήθηκε' : 'Protection enabled')
                                    : (isGreek ? 'Η προστασία απενεργοποιήθηκε' : 'Protection disabled'),
                            );
                          },
                        ),
                        SwitchListTile(
                          secondary: const Icon(Icons.fingerprint),
                          title: Text(isGreek ? 'Biometric Lock' : 'Biometric Lock'),
                          subtitle: Text(isGreek
                              ? 'Κλείδωμα με δακτυλικό αποτύπωμα / Face ID'
                              : 'Lock with fingerprint / Face ID'),
                          value: settings.biometricLockEnabled,
                          onChanged: (v) async {
                            DebugConfig.log(DebugConfig.uiInteraction,
                                'SettingsScreen: biometricLockEnabled=$v');
                            if (v) {
                              final canUse = await LockScreen.canUseBiometric();
                              if (!canUse) {
                                if (context.mounted) {
                                  AppMessenger.showError(context,
                                      isGreek
                                          ? 'Δεν υπάρχει διαθέσιμο βιομετρικό στη συσκευή'
                                          : 'No biometric available on this device',
                                  );
                                }
                                return;
                              }
                            }
                            await ref.read(appSettingsProvider.notifier).setBiometricLock(v);
                            if (context.mounted) {
                              AppMessenger.showInfo(context,
                                  v
                                      ? (isGreek ? 'Biometric Lock ενεργοποιήθηκε' : 'Biometric Lock enabled')
                                      : (isGreek ? 'Biometric Lock απενεργοποιήθηκε' : 'Biometric Lock disabled'),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isAnonymous)
                const Divider(),

              if (!isAnonymous) ...[
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: Text(isGreek ? 'Μπλοκαρισμένοι Χρήστες' : 'Blocked Users'),
                  subtitle: Text(isGreek ? 'Διαχείριση μπλοκαρισμένων χρηστών' : 'Manage blocked users'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/blocked'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: Text(isGreek ? 'Διαγραφή Λογαριασμού' : 'Delete Account'),
                  subtitle: Text(isGreek ? 'Οριστική διαγραφή όλων των δεδομένων' : 'Permanently delete all data'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/delete'),
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: Text(isGreek ? 'Αποσύνδεση' : 'Sign Out'),
                subtitle: Text(isGreek ? 'Αποσύνδεση από τον λογαριασμό' : 'Sign out of your account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _signOut(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}