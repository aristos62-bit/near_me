import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/utils/auth_validation.dart';
import '../../../shared/widgets/forgot_password_dialog.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/save_button.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../core/utils/app_messenger.dart';
import '../providers/auth_provider.dart';

enum _WelcomeMode { login, register }

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  _WelcomeMode _mode = _WelcomeMode.login;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'WelcomeScreen init');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(welcomeProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final notifier = ref.read(welcomeProvider.notifier);
    if (_mode == _WelcomeMode.login) {
      DebugConfig.log(DebugConfig.authFlow, 'WelcomeScreen: login');
      notifier.signIn(email, password);
    } else {
      DebugConfig.log(DebugConfig.authFlow, 'WelcomeScreen: register');
      notifier.signUp(email, password);
    }
  }

  void _browse() {
    DebugConfig.log(DebugConfig.authFlow, 'WelcomeScreen: browse anonymously');
    ref.read(welcomeProvider.notifier).browseAnonymously();
  }

  Future<void> _showForgotPassword() async {
    final email = await showForgotPasswordDialog(context, _emailCtrl.text);
    if (email == null || email.isEmpty) return;
    if (!mounted) return;
    DebugConfig.log(DebugConfig.authFlow, 'WelcomeScreen: password reset for $email');
    ref.read(verifyAccountProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;
    AppMessenger.showSuccess(context,
        ErrorMessages.get('auth/reset-email-sent', L10n.isGreek(context)));
  }

  void _switchMode() {
    setState(() {
      _mode = _mode == _WelcomeMode.login ? _WelcomeMode.register : _WelcomeMode.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final state = ref.watch(welcomeProvider);

    ref.listen<WelcomeState>(welcomeProvider, (prev, next) {
      if (next.status == WelcomeStatus.error && next.errorMessage != null) {
        AppMessenger.showError(context, ErrorMessages.get(next.errorMessage!, L10n.isGreek(context)));
      }
    });

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return Center(
            child: SizedBox(
              width: ResponsiveUtils.maxContentWidthFromWidth(w),
              child: state.status == WelcomeStatus.loading || state.isSignedIn
                  ? const LoadingView()
                  : _buildContent(isGreek, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(bool isGreek, WelcomeState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 48),
            GradientHeader(
              gradientColors: [AppColors.primary, AppColors.primaryDark],
              icon: Icons.near_me_rounded,
              title: L10n.appName(context),
              subtitle: isGreek
                  ? 'Βρες ανθρώπους κοντά σου — για συγκατοίκηση, παρέα, φιλία και δικτύωση'
                  : 'Find people near you — for roommates, social, friendship and networking',
            ),
            const SizedBox(height: 24),
            _buildModeToggle(isGreek),
            const SizedBox(height: 24),
            FormSection(
              title: isGreek ? 'Στοιχεία Λογαριασμού' : 'Account Details',
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  validator: (v) => AuthValidation.validateEmailField(v, isGreek: isGreek),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  validator: (v) => AuthValidation.validatePasswordField(v, isGreek: isGreek),
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
                  textInputAction:
                      _mode == _WelcomeMode.register ? TextInputAction.next : TextInputAction.done,
                  onFieldSubmitted: _mode == _WelcomeMode.register ? null : (_) => _submit(),
                ),
                if (_mode == _WelcomeMode.register) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    validator: (v) => AuthValidation.validateConfirmField(
                        v, _passwordCtrl.text, isGreek: isGreek),
                    decoration: InputDecoration(
                      labelText: isGreek ? 'Επιβεβαίωση Κωδικού' : 'Confirm Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SaveButton(
              isSaving: state.status == WelcomeStatus.loading,
              label: _mode == _WelcomeMode.login
                  ? (isGreek ? 'Είσοδος' : 'Login')
                  : (isGreek ? 'Εγγραφή' : 'Register'),
              onPressed: state.status == WelcomeStatus.loading ? null : _submit,
            ),
            if (_mode == _WelcomeMode.login)
              Center(
                child: TextButton.icon(
                  onPressed: _showForgotPassword,
                  icon: const Icon(Icons.lock_reset_outlined, size: 18),
                  label: Text(isGreek ? 'Ξέχασες τον κωδικό;' : 'Forgot password?'),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _switchMode,
              child: Text(
                _mode == _WelcomeMode.login
                    ? (isGreek ? 'Δεν έχεις λογαριασμό; Εγγράψου' : "Don't have an account? Register")
                    : (isGreek ? 'Έχεις ήδη λογαριασμό; Είσοδος' : 'Already have an account? Login'),
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      L10n.localizedMessage(context, 'ή / or'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _browse,
                icon: const Icon(Icons.explore_outlined, size: 20),
                label: Text(isGreek ? 'Περιήγηση χωρίς λογαριασμό' : 'Browse without account'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isGreek
                  ? 'Μπορείς να περιηγηθείς ανώνυμα. Για αποστολή μηνυμάτων θα χρειαστεί επαλήθευση.'
                  : 'You can browse anonymously. Verification is required to send messages.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(bool isGreek) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = _WelcomeMode.login),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == _WelcomeMode.login
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isGreek ? 'Είσοδος' : 'Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mode == _WelcomeMode.login
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = _WelcomeMode.register),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == _WelcomeMode.register
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isGreek ? 'Εγγραφή' : 'Register',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mode == _WelcomeMode.register
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
