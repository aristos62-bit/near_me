import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/utils/auth_validation.dart';

void main() {
  group('isValidEmail/isValidPassword', () {
    test('έγκυρο email', () {
      expect(AuthValidation.isValidEmail('a@b.gr'), isTrue);
    });

    test('άκυρα email', () {
      expect(AuthValidation.isValidEmail(''), isFalse);
      expect(AuthValidation.isValidEmail('plain'), isFalse);
      expect(AuthValidation.isValidEmail('a@b'), isFalse);
      expect(AuthValidation.isValidEmail(null), isFalse);
    });

    test('κωδικός ορίου 6', () {
      expect(AuthValidation.isValidPassword('123456'), isTrue);
      expect(AuthValidation.isValidPassword('12345'), isFalse);
      expect(AuthValidation.isValidPassword(null), isFalse);
    });
  });

  group('validateEmailField/validatePasswordField/validateConfirmField', () {
    test('άκυρο email → auth/invalid-email message', () {
      expect(
          AuthValidation.validateEmailField('bad', isGreek: true), isNotEmpty);
      expect(AuthValidation.validateEmailField('a@b.gr', isGreek: true), isNull);
    });

    test('κοντός κωδικός → auth/weak-password message', () {
      expect(AuthValidation.validatePasswordField('123', isGreek: true),
          isNotEmpty);
      expect(AuthValidation.validatePasswordField('123456', isGreek: true),
          isNull);
    });

    test('mismatch → auth/passwords-mismatch message', () {
      expect(
          AuthValidation.validateConfirmField('x', 'y', isGreek: true),
          'Οι κωδικοί δεν ταιριάζουν');
      expect(
          AuthValidation.validateConfirmField('same', 'same', isGreek: true),
          isNull);
    });
  });

  group('normalizePhone (leading-0 fix)', () {
    test('069... με +30 → +3069... (κόβεται το 0)', () {
      expect(AuthValidation.normalizePhone('0691234567', '+30'),
          '+30691234567');
    });

    test('69... με +30 → +3069...', () {
      expect(
          AuthValidation.normalizePhone('691234567', '+30'), '+30691234567');
    });

    test('spaces αγνοούνται', () {
      expect(AuthValidation.normalizePhone('69 123 4567', '+30'),
          '+30691234567');
    });

    test('πλήρες +30691234567 μένει ως έχει', () {
      expect(AuthValidation.normalizePhone('+30691234567', '+30'),
          '+30691234567');
    });

    test('πολλά αρχικά 0 κόβονται', () {
      expect(
          AuthValidation.normalizePhone('00691234567', '+30'), '+30691234567');
    });

    test('πολύ κοντός → null', () {
      expect(AuthValidation.normalizePhone('123', '+30'), isNull);
      expect(AuthValidation.normalizePhone('ABC', '+30'), isNull);
      expect(AuthValidation.normalizePhone('', '+30'), isNull);
    });

    test('validatePhoneField: άκυρο → invalid-phone, έγκυρο → null', () {
      expect(AuthValidation.validatePhoneField('123', '+30', isGreek: true),
          isNotEmpty);
      expect(
          AuthValidation.validatePhoneField('691234567', '+30',
              isGreek: true),
          isNull);
    });
  });

  group('validateOtpField', () {
    test('6 ψηφία → null', () {
      expect(AuthValidation.validateOtpField('123456', isGreek: true), isNull);
    });

    test('κενό/κοντό/μη-αριθμητικό → invalid-code', () {
      expect(AuthValidation.validateOtpField('', isGreek: true), isNotEmpty);
      expect(
          AuthValidation.validateOtpField('123', isGreek: true), isNotEmpty);
      expect(
          AuthValidation.validateOtpField('abcdef', isGreek: true), isNotEmpty);
    });
  });
}
