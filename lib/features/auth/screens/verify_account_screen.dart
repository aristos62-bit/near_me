import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/save_button.dart';
import '../providers/auth_provider.dart';

class VerifyAccountScreen extends ConsumerStatefulWidget {
  const VerifyAccountScreen({super.key});
  @override
  ConsumerState<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends ConsumerState<VerifyAccountScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  Timer? _verifyTimer;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'VerifyAccountScreen init');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(verifyAccountProvider.notifier).reset();
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null && !user.isAnonymous && !user.emailVerified) {
        ref.read(verifyAccountProvider.notifier).showEmailSent();
        _startVerifyTimer();
      }
    });
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _startVerifyTimer() {
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(verifyAccountProvider.notifier).checkVerificationSilent();
    });
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccountScreen: auto-verify timer started');
  }

  bool get _isLinked {
    final user = ref.read(authRepositoryProvider).currentUser;
    return user != null && !user.isAnonymous;
  }

  void _verify() {
    if (_isLinked) {
      DebugConfig.log(DebugConfig.authFlow, 'VerifyAccountScreen: resend verification');
      ref.read(verifyAccountProvider.notifier).verify('', '');
      return;
    }
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      AppMessenger.showError(context, L10n.localizedMessage(context,
          'Συμπλήρωσε όλα τα πεδία / Fill in all fields'));
      return;
    }
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccountScreen: verify tapped');
    ref.read(verifyAccountProvider.notifier).verify(email, password);
  }

  void _checkVerification() {
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccountScreen: check verification');
    ref.read(verifyAccountProvider.notifier).checkVerification();
  }

  void _showForgotPassword() {
    final isGreek = L10n.isGreek(context);
    final resetCtrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(L10n.localizedMessage(context, 'Ξέχασες τον κωδικό; / Forgot Password?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(L10n.localizedMessage(context, 'Θα σου στείλουμε email επαναφοράς κωδικού / We will send you a password reset email')),
            const SizedBox(height: 16),
            TextField(
              controller: resetCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              resetCtrl.dispose();
            },
            child: Text(isGreek ? 'Ακύρωση' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = resetCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();
              resetCtrl.dispose();
              DebugConfig.log(DebugConfig.authFlow, 'VerifyAccountScreen: password reset for $email');
              ref.read(verifyAccountProvider.notifier).sendPasswordReset(email);
              AppMessenger.showSuccess(context,
                  L10n.localizedMessage(context, 'Στάλθηκε email επαναφοράς / Reset email sent'));
            },
            child: Text(isGreek ? 'Αποστολή' : 'Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final state = ref.watch(verifyAccountProvider);
    final isLinked = _isLinked;
    DebugConfig.log(DebugConfig.uiInteraction,
        'VerifyAccountScreen build: ${state.status}, isLinked=$isLinked');

    ref.listen<VerifyAccountState>(verifyAccountProvider, (prev, next) {
      if (next.status == VerifyStatus.emailSent && prev?.status != VerifyStatus.emailSent) {
        _startVerifyTimer();
      }
      if (next.status == VerifyStatus.verified && prev?.status != VerifyStatus.verified) {
        _verifyTimer?.cancel();
        DebugConfig.log(DebugConfig.authFlow, 'VerifyAccountScreen: verified, auto-navigating');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // ignore: use_build_context_synchronously
            context.go('/');
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            DebugConfig.log(DebugConfig.uiInteraction, 'VerifyAccountScreen: user dismissed');
            _verifyTimer?.cancel();
            AppRouter.dismissVerify();
            context.go('/');
          },
        ),
        title: Text(isGreek ? 'Επαλήθευση Λογαριασμού' : 'Verify Account'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return Center(
            child: SizedBox(
              width: ResponsiveUtils.maxContentWidthFromWidth(w),
              child: switch (state.status) {
            VerifyStatus.loading => const LoadingView(),
            VerifyStatus.verified => _buildVerified(isGreek),
            _ => _buildForm(isGreek, state, isLinked: isLinked),
          },
        ),
        );
        },
      ),
    );
  }

  Widget _buildForm(bool isGreek, VerifyAccountState state, {required bool isLinked}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        GradientHeader(
          gradientColors: [AppColors.primary, AppColors.primaryDark],
          icon: Icons.mail_outline_rounded,
          title: isGreek ? 'Επιβεβαίωσε τον λογαριασμό σου' : 'Verify Your Account',
          subtitle: isLinked
              ? (isGreek
                  ? 'Σου έχουμε στείλει email. Πάτα τον σύνδεσμο για επαλήθευση.'
                  : 'We sent you an email. Click the link to verify.')
              : (isGreek
                  ? 'Σύνδεσε email και κωδικό για να ενεργοποιήσεις τις λειτουργίες επικοινωνίας'
                  : 'Link email and password to enable communication features'),
        ),
        const SizedBox(height: 8),
        if (state.status == VerifyStatus.error && state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ErrorView(message: ErrorMessages.get(state.errorMessage!, isGreek)),
          ),
        if (!isLinked)
          FormSection(
            title: isGreek ? 'Στοιχεία Λογαριασμού' : 'Account Details',
            children: [
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: isGreek ? 'Κωδικός' : 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ],
          ),
        if (state.status == VerifyStatus.emailSent)
          FormSection(
            title: isGreek ? 'Email Στάλθηκε' : 'Email Sent',
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isGreek
                          ? 'Σου στείλαμε email επαλήθευσης. Έλεγξε τα εισερχόμενα σου και κάνε κλικ στο σύνδεσμο.'
                          : 'We sent you a verification email. Check your inbox and click the link.',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (!isLinked)
                const SizedBox(height: 12),
              if (!isLinked)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checkVerification,
                    icon: const Icon(Icons.refresh_outlined, size: 18),
                    label: Text(isGreek ? 'Έλεγξα, συνέχισε' : 'I verified, continue'),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        SaveButton(
          isSaving: false,
          label: state.status == VerifyStatus.emailSent
              ? (isGreek ? 'Ξαναποστολή Email' : 'Resend Email')
              : (isGreek ? 'Αποστολή Επαλήθευσης' : 'Send Verification'),
          onPressed: _verify,
        ),
        const SizedBox(height: 12),
        if (isLinked && state.status == VerifyStatus.emailSent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              isGreek
                  ? 'Η επαλήθευση ελέγχεται αυτόματα. Εάν δεν βλέπεις το email, έλεγξε και στα Ανεπιθυμητά.'
                  : 'Verification is checked automatically. If you don\'t see the email, check your Spam folder.',
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (isLinked)
          Center(
            child: TextButton.icon(
              onPressed: _showForgotPassword,
              icon: const Icon(Icons.lock_reset_outlined, size: 18),
              label: Text(isGreek ? 'Ξέχασες τον κωδικό;' : 'Forgot password?'),
            ),
          ),
      ],
    );
  }

  Widget _buildVerified(bool isGreek) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          Text(
            isGreek ? 'Ο λογαριασμός επαληθεύτηκε!' : 'Account Verified!',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isGreek
                ? 'Τώρα μπορείς να στείλεις αιτήματα και να συνομιλήσεις με άλλους χρήστες.'
                : 'Now you can send requests and chat with other users.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
              label: Text(isGreek ? 'Αρχική' : 'Home'),
            ),
          ),
        ],
      ),
    );
  }

}