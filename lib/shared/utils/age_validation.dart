import '../../core/utils/error_messages.dart';

/// SPoT για έλεγχο ηλικίας / έτους γέννησης (age gating 18+).
class AgeValidation {
  AgeValidation._();

  /// Ελάχιστο αποδεκτό έτος γέννησης.
  static const int minBirthYear = 1900;

  /// Υπολογισμός ηλικίας από έτος γέννησης (null-safe).
  static int? ageFromBirthYear(int? birthYear) =>
      birthYear == null ? null : DateTime.now().year - birthYear;

  /// Ελάχιστη ηλικία για χρήση: 18 ετών (υπολογισμός με έτος).
  static bool isAdultBirthYear(int? birthYear) {
    final age = ageFromBirthYear(birthYear);
    return age != null && age >= 18;
  }

  /// Εύλογο έτος γέννησης: 1900..τρέχον έτος.
  static bool isPlausibleBirthYear(int? birthYear) {
    if (birthYear == null) return false;
    final now = DateTime.now();
    return birthYear >= minBirthYear && birthYear <= now.year;
  }

  /// Validator για TextFormField: επιστρέφει error message ή null.
  /// Κενό → birth-year-required · μη-αριθμητικό/εκτός range → birth-year-invalid ·
  /// ηλικία <18 → min-age-required.
  static String? validateBirthYearField(String? text, {required bool isGreek}) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return ErrorMessages.get('profile/birth-year-required', isGreek);
    final year = int.tryParse(t);
    if (year == null) return ErrorMessages.get('profile/birth-year-invalid', isGreek);
    if (!isPlausibleBirthYear(year)) return ErrorMessages.get('profile/birth-year-invalid', isGreek);
    if (!isAdultBirthYear(year)) return ErrorMessages.get('profile/min-age-required', isGreek);
    return null;
  }
}