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
  bool _phoneVerified = false; // ← ΝΕΟ: cached, δεν υπολογίζεται στο build()

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'SettingsScreen init');
    _authUser = ref.read(authStateProvider).value;
    _phoneVerified = _computePhoneVerified(_authUser);
  }

  bool _computePhoneVerified(User? user) {
    if (user == null || (user.isAnonymous)) return false;
    return ref.read(authRepositoryProvider).isPhoneVerified;
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
      // Ενημέρωση άμεσα χωρίς να περιμένουμε authStateChanges emission
      final updatedUser = ref.read(authRepositoryProvider).currentUser;
      setState(() {
        _authUser = updatedUser;
        _phoneVerified = _computePhoneVerified(updatedUser);
      });
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
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      final newUser = next.value;
      final uidChanged     = _authUser?.uid         != newUser?.uid;
      final anonChanged    = _authUser?.isAnonymous != newUser?.isAnonymous;
      final verifiedChanged= _authUser?.emailVerified != newUser?.emailVerified;
      final phoneChanged   = _authUser?.phoneNumber != newUser?.phoneNumber;

      if (uidChanged || anonChanged || verifiedChanged || phoneChanged) {
        DebugConfig.log(DebugConfig.uiInteraction,
            'SettingsScreen: user changed → rebuild');
        if (mounted) {
          setState(() {
            _authUser = newUser;
            _phoneVerified = _computePhoneVerified(newUser);
          });
        }
      }
    });
    final isGreek = L10n.isGreek(context);
    final isAnonymous   = _authUser?.isAnonymous ?? false;
    final emailVerified = _authUser?.emailVerified ?? false;
    // _phoneVerified έρχεται από cached state — ΟΧΙ ref.read εδώ

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: Text(isGreek ? 'Ρυθμίσεις' : 'Settings'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return Center(
            child: SizedBox(
              width: ResponsiveUtils.maxContentWidthFromWidth(w),
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
                  subtitle: Text(_phoneVerified
                      ? (isGreek ? 'Επαληθεύτηκε' : 'Verified')
                      : (isGreek
                      ? 'Επιβεβαίωσε τον αριθμό τηλεφώνου σου'
                      : 'Verify your phone number')),
                  trailing: _phoneVerified
                      ? Icon(Icons.check_circle, color: AppColors.online)
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/phone-verify'),
                ),
                if (_phoneVerified)
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
    );
    },
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
            if (settings.biometricLockEnabled)
              _AutoLockTile(currentMinutes: settings.autoLockMinutes),
          ],
        ),
      ),
    );
  }
}

class _AutoLockTile extends ConsumerStatefulWidget {
  final int currentMinutes;
  const _AutoLockTile({required this.currentMinutes});

  @override
  ConsumerState<_AutoLockTile> createState() => _AutoLockTileState();
}

class _AutoLockTileState extends ConsumerState<_AutoLockTile> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMinutes;
  }

  @override
  void didUpdateWidget(covariant _AutoLockTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentMinutes != oldWidget.currentMinutes) {
      _selected = widget.currentMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);

    return ResponsivePadding(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(L10n.autoLockTitle(isGreek: isGreek)),
            subtitle: Text(L10n.autoLockSubtitle(_selected, isGreek: isGreek)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('1', style: Theme.of(context).textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    value: _selected.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '$_selected min',
                    semanticFormatterCallback: (v) => '${v.round()} minutes',
                    onChanged: (v) {
                      final rounded = v.round();
                      if (rounded == _selected) return;
                      setState(() {
                        _selected = rounded;
                      });
                      DebugConfig.log(DebugConfig.uiInteraction,
                          '_AutoLockTile: onChanged minutes=$rounded');
                    },
                    onChangeEnd: (v) async {
                      final finalValue = v.round();
                      DebugConfig.log(DebugConfig.uiInteraction,
                          '_AutoLockTile: onChangeEnd minutes=$finalValue');
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setAutoLockMinutes(finalValue);
                      if (context.mounted) {
                        AppMessenger.showSuccess(context,
                            L10n.autoLockUpdated(finalValue, isGreek: isGreek));
                      }
                    },
                  ),
                ),
                Text('30', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
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