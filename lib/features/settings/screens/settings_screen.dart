import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/lock_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  User? _authUser;
  bool _isUnlinking = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'SettingsScreen init');
    _authUser = ref.read(authStateProvider).value;
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      final newUser = next.value;
      if (_authUser?.uid != newUser?.uid ||
          _authUser?.isAnonymous != newUser?.isAnonymous ||
          _authUser?.emailVerified != newUser?.emailVerified ||
          _authUser?.phoneNumber != newUser?.phoneNumber) {
        if (mounted) setState(() => _authUser = newUser);
      }
    });
  }

  @override
  void dispose() {
    DebugConfig.log(DebugConfig.uiInteraction, 'SettingsScreen dispose');
    super.dispose();
  }

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

  Future<void> _unlinkPhone() async {
    final isGreek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Αφαίρεση Τηλεφώνου / Remove Phone'),
      message: L10n.localizedMessage(context,
          'Το τηλέφωνο θα αφαιρεθεί από τον λογαριασμό σου. Μπορείς να το επαληθεύσεις ξανά αργότερα. / The phone will be removed from your account. You can re-verify it later.'),
      confirmLabel: isGreek ? 'Αφαίρεση' : 'Remove',
      cancelLabel: isGreek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;
    DebugConfig.log(DebugConfig.uiInteraction, 'SettingsScreen: unlink phone');
    setState(() => _isUnlinking = true);
    try {
      await ref.read(authRepositoryProvider).unlinkPhone();
      DebugConfig.log(DebugConfig.uiInteraction, 'SettingsScreen: phone unlinked');
      if (!mounted) return;
      setState(() => _authUser = ref.read(authRepositoryProvider).currentUser);
      AppMessenger.showSuccess(context,
          L10n.localizedMessage(context, 'Το τηλέφωνο αφαιρέθηκε / Phone removed'));
    } catch (e) {
      DebugConfig.error('SettingsScreen: unlink phone failed', exception: e);
      if (!mounted) return;
      AppMessenger.showError(context,
          L10n.localizedMessage(context, 'Αποτυχία αφαίρεσης / Remove failed'));
    } finally {
      if (mounted) setState(() => _isUnlinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final isAnonymous = _authUser?.isAnonymous ?? false;
    final emailVerified = _authUser?.emailVerified ?? false;
    final phoneVerified = !isAnonymous && ref.read(authRepositoryProvider).isPhoneVerified;
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

              if (!isAnonymous && emailVerified) ...[
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
                if (phoneVerified)
                  ListTile(
                    leading: const Icon(Icons.phone_disabled_outlined),
                    title: Text(isGreek ? 'Αφαίρεση Τηλεφώνου' : 'Remove Phone'),
                    subtitle: Text(isGreek
                        ? 'Αφαίρεσε τον αριθμό από τον λογαριασμό σου'
                        : 'Remove number from your account'),
                    enabled: !_isUnlinking,
                    trailing: _isUnlinking
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right),
                    onTap: _isUnlinking ? null : _unlinkPhone,
                  ),
                const Divider(),
              ],

              // --- Ασφάλεια Συσκευής ---
              if (!isAnonymous)
                _SectionHeader(label: isGreek ? 'Ασφάλεια Συσκευής' : 'Device Security'),
              if (!isAnonymous)
                const _DeviceSecuritySection(),
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

class _DeviceSecuritySection extends ConsumerWidget {
  const _DeviceSecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGreek = L10n.isGreek(context);
    final appSettingsAsync = ref.watch(appSettingsProvider);
    DebugConfig.log(DebugConfig.uiInteraction, '_DeviceSecuritySection build');

    return Padding(
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
                    '_DeviceSecuritySection: screenshotPreventionEnabled=$v');
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
                    '_DeviceSecuritySection: biometricLockEnabled=$v');
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
