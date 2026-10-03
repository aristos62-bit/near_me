import 'package:flutter/material.dart';
import '../../core/debug/debug_config.dart';
import '../../core/l10n/l10n.dart';
import '../utils/auth_validation.dart';

/// SPoT dialog "Ξέχασες τον κωδικό;" — ίδιο API με `showReportUserDialog`:
/// free function που επιστρέφει το email (ή null σε ακύρωση).
/// Το περιεχόμενο είναι private StatefulWidget (input + send).
Future<String?> showForgotPasswordDialog(
  BuildContext context,
  String initialEmail,
) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ForgotPasswordBody(initialEmail: initialEmail),
  );
}

class _ForgotPasswordBody extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordBody({required this.initialEmail});

  @override
  State<_ForgotPasswordBody> createState() => _ForgotPasswordBodyState();
}

class _ForgotPasswordBodyState extends State<_ForgotPasswordBody> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(L10n.localizedMessage(
          context, 'Ξέχασες τον κωδικό; / Forgot Password?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L10n.localizedMessage(context,
              'Θα σου στείλουμε email επαναφοράς κωδικού / We will send you a password reset email')),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: 'Email',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email_outlined),
              errorText: _error,
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isGreek ? 'Ακύρωση' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final err = AuthValidation.validateEmailField(_ctrl.text.trim(),
                isGreek: isGreek);
            if (err != null) {
              setState(() => _error = err);
              return;
            }
            DebugConfig.log(DebugConfig.authFlow,
                'ForgotPasswordDialog: password reset for ${_ctrl.text.trim()}');
            Navigator.of(context).pop(_ctrl.text.trim());
          },
          child: Text(isGreek ? 'Αποστολή' : 'Send'),
        ),
      ],
    );
  }
}
