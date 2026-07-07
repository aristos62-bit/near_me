import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
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

  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    bool valid = true;

    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _emailError = 'Μη έγκυρο email / Invalid email';
      valid = false;
    }
    if (password.length < 6) {
      _passwordError = 'Τουλάχιστον 6 χαρακτήρες / At least 6 characters';
      valid = false;
    }
    if (_mode == _WelcomeMode.register) {
      if (_confirmCtrl.text != password) {
        _confirmError = 'Οι κωδικοί δεν ταιριάζουν / Passwords do not match';
        valid = false;
      }
    }
    return valid;
  }

  void _submit() {
    if (!_validate()) return;
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

  void _switchMode() {
    setState(() {
      _mode = _mode == _WelcomeMode.login ? _WelcomeMode.register : _WelcomeMode.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final state = ref.watch(welcomeProvider);
    DebugConfig.log(DebugConfig.uiInteraction, 'WelcomeScreen build: ${state.status}');

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
      child: Column(
        children: [
          const SizedBox(height: 48),
          GradientHeader(
            gradientColors: [AppColors.primary, AppColors.primaryDark],
            icon: Icons.near_me_rounded,
            title: 'NearMe',
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
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: _emailError != null ? L10n.localizedMessage(context, _emailError!) : null,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: isGreek ? 'Κωδικός' : 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outlined),
                  errorText: _passwordError != null ? L10n.localizedMessage(context, _passwordError!) : null,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction:
                    _mode == _WelcomeMode.register ? TextInputAction.next : TextInputAction.done,
                onSubmitted: _mode == _WelcomeMode.register ? null : (_) => _submit(),
              ),
              if (_mode == _WelcomeMode.register) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: isGreek ? 'Επιβεβαίωση Κωδικού' : 'Confirm Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    errorText: _confirmError != null ? L10n.localizedMessage(context, _confirmError!) : null,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ή', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
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
