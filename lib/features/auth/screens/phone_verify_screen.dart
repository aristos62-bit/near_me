import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/save_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/phone_verify_provider.dart';

class PhoneVerifyScreen extends ConsumerStatefulWidget {
  const PhoneVerifyScreen({super.key});

  @override
  ConsumerState<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends ConsumerState<PhoneVerifyScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _otpFormActive = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'PhoneVerifyScreen init');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(phoneVerifyProvider.notifier);
      notifier.reset();
      notifier.checkIfAlreadyVerified();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final g = L10n.isGreek(context);
    final code = L10n.phoneCountryCode();
    var phone = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (!phone.startsWith('+')) {
      phone = '$code$phone';
    }
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final phonePattern = RegExp(r'^[1-9]\d{6,14}$');
    if (!phonePattern.hasMatch(phone)) {
      AppMessenger.showError(
        context,
        g ? 'Μη έγκυρος αριθμός τηλεφώνου' : 'Invalid phone number',
      );
      return;
    }
    phone = '+$phone';
    DebugConfig.log(DebugConfig.authPhone, 'PhoneVerifyScreen: sendOtp $phone');
    if (_otpFormActive) {
      _otpCtrl.clear();
    }
    setState(() => _isSending = true);
    await ref.read(phoneVerifyProvider.notifier).sendOtp(phone);
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.isEmpty) {
      final g = L10n.isGreek(context);
      AppMessenger.showError(context, g ? 'Συμπλήρωσε τον κωδικό' : 'Enter the verification code');
      return;
    }
    DebugConfig.log(DebugConfig.authPhone, 'PhoneVerifyScreen: verifyOtp');
    setState(() => _isVerifying = true);
    await ref.read(phoneVerifyProvider.notifier).verifyOtp(code);
    if (mounted) setState(() => _isVerifying = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = L10n.isGreek(context);
    final user = ref.watch(authStateProvider).value;
    final isAnonymous = user?.isAnonymous ?? true;
    final isEmailVerified = user?.emailVerified ?? false;
    final state = ref.watch(phoneVerifyProvider);
    final theme = Theme.of(context);

    ref.listen<PhoneVerifyState>(phoneVerifyProvider, (prev, next) {
      if (next.status == PhoneVerifyStatus.otpSent && !_otpFormActive) {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerifyScreen: OTP form active');
        if (mounted) setState(() => _otpFormActive = true);
      }
      if (next.status == PhoneVerifyStatus.idle && _otpFormActive) {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerifyScreen: OTP form inactive (idle)');
        if (mounted) setState(() => _otpFormActive = false);
      }
      // ΝΕΟ: Σε error κατά το send (όχι verify), κλείνουμε το OTP form
      if (next.status == PhoneVerifyStatus.error && _otpFormActive) {
        // Αν ήταν error κατά το sendOtp (prev ήταν loading πριν otpSent)
        // Μόνο αν δεν είχαμε ποτέ otpSent → κλείνουμε
        final hadOtpSent = prev?.status == PhoneVerifyStatus.otpSent ||
            prev?.verificationId != null;
        if (!hadOtpSent) {
          DebugConfig.log(DebugConfig.authPhone, 'PhoneVerifyScreen: OTP form inactive (send error)');
          if (mounted) setState(() => _otpFormActive = false);
        }
      }
    });

    if (isAnonymous || !isEmailVerified) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton(), title: Text(g ? 'Επαλήθευση Τηλεφώνου' : 'Phone Verification')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_disabled_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
                const SizedBox(height: 16),
                Text(
                  g ? 'Η επαλήθευση τηλεφώνου δεν είναι διαθέσιμη' : 'Phone verification not available',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isAnonymous
                      ? (g ? 'Πρέπει πρώτα να επαληθεύσεις τον λογαριασμό σου με email.' : 'You must first verify your account with email.')
                      : (g ? 'Πρέπει πρώτα να επιβεβαιώσεις το email σου.' : 'You must first verify your email.'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/auth'),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: Text(g ? 'Επαλήθευση Email' : 'Verify Email'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(g ? 'Επαλήθευση Τηλεφώνου' : 'Phone Verification'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return Center(
            child: SizedBox(
              width: ResponsiveUtils.maxContentWidthFromWidth(w),
              child: state.status == PhoneVerifyStatus.autoVerified
              ? _buildAutoVerified(g, theme)
              : state.status == PhoneVerifyStatus.verified
                  ? _buildVerified(g, theme)
                  : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              children: [
                                GradientHeader(
                                  gradientColors: [AppColors.primary, AppColors.primaryDark.withAlpha(220)],
                                  icon: Icons.phone_android_outlined,
                                  title: g ? 'Επαλήθευση Τηλεφώνου' : 'Phone Verification',
                                  subtitle: g
                                      ? 'Θα λάβεις έναν κωδικό μέσω SMS'
                                      : 'You will receive a code via SMS',
                                ),
                                if (state.status == PhoneVerifyStatus.error && state.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                    child: ErrorView(
                                      message: ErrorMessages.get(state.errorMessage!, g),
                                      onRetry: () => ref.read(phoneVerifyProvider.notifier).reset(),
                                    ),
                                  ),
                                if (!_otpFormActive) ...[
                                  FormSection(
                                    title: g ? 'Αριθμός Τηλεφώνου' : 'Phone Number',
                                    children: [
                                      TextFormField(
                                        controller: _phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        enabled: !_isSending,
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                          prefixText: '${L10n.phoneCountryCode()} ',
                                          labelText: g ? '6XX XXXXXXX' : 'XXX XXX XXXX',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                    child: SaveButton(
                                      isSaving: _isSending,
                                      label: g ? 'Αποστολή Κωδικού' : 'Send Code',
                                      onPressed: _sendOtp,
                                    ),
                                  ),
                                ],
                                if (_otpFormActive) ...[
                                  FormSection(
                                    title: g ? 'Κωδικός Επαλήθευσης' : 'Verification Code',
                                    children: [
                                      TextFormField(
                                        controller: _otpCtrl,
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        enabled: !_isVerifying,
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                                          labelText: g ? '6-ψήφιος κωδικός' : '6-digit code',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                    child: SaveButton(
                                      isSaving: _isVerifying,
                                      label: g ? 'Επαλήθευση' : 'Verify',
                                      onPressed: _verifyOtp,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _isSending ? null : _sendOtp,
                                    icon: _isSending
                                        ? SizedBox(
                                            width: 18, height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.refresh_outlined, size: 18),
                                    label: Text(g ? 'Επαναποστολή κωδικού' : 'Resend code'),
                                  ),
                                ],
                              ],
                            ),
        ),
      );
      },
    ),
    );
  }

  Widget _buildAutoVerified(bool g, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 72, color: AppColors.online),
          const SizedBox(height: 16),
          Text(
            g ? 'Το τηλέφωνο επαληθεύτηκε αυτόματα!' : 'Phone auto-verified!',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check, size: 18),
            label: Text(g ? 'ΟΚ' : 'OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerified(bool g, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 72, color: AppColors.online),
          const SizedBox(height: 16),
          Text(
            g ? 'Το τηλέφωνο επαληθεύτηκε!' : 'Phone verified!',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check, size: 18),
            label: Text(g ? 'ΟΚ' : 'OK'),
          ),
        ],
      ),
    );
  }

}
