import '../../core/utils/error_messages.dart';

/// SPoT για validation φορμών ταυτοποίησης (welcome / verify / phone).
/// Ακριβές pattern του [AgeValidation]: static pure, υπογραφές
/// `(String?, {required isGreek}) → String?` για απευθείας χρήση σε
/// `TextFormField.validator` (βλ. `profile_editor_screen`).
class AuthValidation {
  AuthValidation._();

  static final RegExp emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  /// Αριθμός 7-15 ψηφία, πρώτο ψηφίο 1-9 (ίδιο με `phone_verify_screen`).
  static final RegExp phoneDigitsPattern = RegExp(r'^[1-9]\d{6,14}$');

  static const int minPasswordLength = 6;
  static const int otpLength = 6;

  static bool isValidEmail(String? text) =>
      text != null && emailPattern.hasMatch(text.trim());

  static bool isValidPassword(String? text) =>
      text != null && text.length >= minPasswordLength;

  /// Validator email: κενό/άκυρο → `auth/invalid-email`, αλλιώς null.
  static String? validateEmailField(String? text, {required bool isGreek}) {
    if (!isValidEmail(text)) {
      return ErrorMessages.get('auth/invalid-email', isGreek);
    }
    return null;
  }

  /// Validator κωδικού: <6 χαρακτήρες → `auth/weak-password`, αλλιώς null.
  static String? validatePasswordField(String? text, {required bool isGreek}) {
    if (!isValidPassword(text)) {
      return ErrorMessages.get('auth/weak-password', isGreek);
    }
    return null;
  }

  /// Validator επιβεβαίωσης: mismatch → `auth/passwords-mismatch`, αλλιώς null.
  static String? validateConfirmField(String? confirm, String password,
      {required bool isGreek}) {
    if (confirm != password) {
      return ErrorMessages.get('auth/passwords-mismatch', isGreek);
    }
    return null;
  }

  /// Κανονικοποίηση τηλεφώνου: spaces έξω → κοπή αρχικών `0` του
  /// national part → prefix `code` αν λείπει το `+`.
  /// `'0691234567'` + `'+30'` → `'+30691234567'` (leading-0 fix, Γ6).
  /// Επιστρέφει null αν δεν βγαίνει έγκυρος αριθμός.
  static String? normalizePhone(String raw, String code) {
    var phone = raw.trim().replaceAll(' ', '');
    if (phone.startsWith('+')) {
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!phoneDigitsPattern.hasMatch(digits)) return null;
      return '+$digits';
    }
    var national = phone.replaceAll(RegExp(r'[^\d]'), '');
    national = national.replaceAll(RegExp(r'^0+'), '');
    final digits = '${code.replaceAll(RegExp(r'[^\d]'), '')}$national';
    if (!phoneDigitsPattern.hasMatch(digits)) return null;
    return '+$digits';
  }

  /// Validator τηλεφώνου: άκυρο → `auth/invalid-phone`, αλλιώς null.
  static String? validatePhoneField(String? text, String code,
      {required bool isGreek}) {
    if (text == null || normalizePhone(text, code) == null) {
      return ErrorMessages.get('auth/invalid-phone', isGreek);
    }
    return null;
  }

  /// Validator OTP: όχι ακριβώς 6 ψηφία → `auth/invalid-code`, αλλιώς null.
  static String? validateOtpField(String? text, {required bool isGreek}) {
    final t = text?.trim() ?? '';
    if (t.length != otpLength || int.tryParse(t) == null) {
      return ErrorMessages.get('auth/invalid-code', isGreek);
    }
    return null;
  }
}
