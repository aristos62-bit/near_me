import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/utils/age_validation.dart';

void main() {
  group('ageFromBirthYear', () {
    test('null year returns null age', () {
      expect(AgeValidation.ageFromBirthYear(null), isNull);
    });

    test('calculates age from birth year', () {
      final nowYear = DateTime.now().year;
      expect(AgeValidation.ageFromBirthYear(nowYear - 30), 30);
    });
  });

  group('isAdultBirthYear', () {
    test('exactly 18 is adult', () {
      final nowYear = DateTime.now().year;
      expect(AgeValidation.isAdultBirthYear(nowYear - 18), isTrue);
    });

    test('17 is not adult', () {
      final nowYear = DateTime.now().year;
      expect(AgeValidation.isAdultBirthYear(nowYear - 17), isFalse);
    });

    test('null birth year is not adult', () {
      expect(AgeValidation.isAdultBirthYear(null), isFalse);
    });
  });

  group('isPlausibleBirthYear', () {
    test('accepts min boundary (1900)', () {
      expect(AgeValidation.isPlausibleBirthYear(AgeValidation.minBirthYear), isTrue);
    });

    test('accepts current year', () {
      expect(AgeValidation.isPlausibleBirthYear(DateTime.now().year), isTrue);
    });

    test('rejects year before 1900', () {
      expect(AgeValidation.isPlausibleBirthYear(1899), isFalse);
    });

    test('rejects future year', () {
      expect(AgeValidation.isPlausibleBirthYear(DateTime.now().year + 1), isFalse);
    });

    test('rejects null', () {
      expect(AgeValidation.isPlausibleBirthYear(null), isFalse);
    });
  });

  group('validateBirthYearField', () {
    test('empty returns birth-year-required', () {
      expect(AgeValidation.validateBirthYearField('', isGreek: true), isNotEmpty);
      expect(AgeValidation.validateBirthYearField('   ', isGreek: true), isNotEmpty);
    });

    test('non-numeric returns invalid', () {
      expect(AgeValidation.validateBirthYearField('abc', isGreek: true), isNotEmpty);
    });

    test('plausible but under 18 returns min-age-required', () {
      final nowYear = DateTime.now().year;
      expect(AgeValidation.validateBirthYearField('$nowYear', isGreek: true), isNotEmpty);
    });

    test('valid adult year returns null', () {
      final nowYear = DateTime.now().year;
      expect(AgeValidation.validateBirthYearField('${nowYear - 30}', isGreek: true), isNull);
    });
  });
}
