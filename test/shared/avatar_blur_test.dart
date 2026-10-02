import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/utils/avatar_blur.dart';

/// `avatar_blur` SPoT — pure, χωρίς pump (τα Widgets είναι απλά objects).
void main() {
  group('isRacyLevel', () {
    test('POSSIBLE/LIKELY/VERY_LIKELY → true', () {
      expect(isRacyLevel('POSSIBLE'), isTrue);
      expect(isRacyLevel('LIKELY'), isTrue);
      expect(isRacyLevel('VERY_LIKELY'), isTrue);
    });

    test('VERY_UNLIKELY/null/άλλο → false', () {
      expect(isRacyLevel('VERY_UNLIKELY'), isFalse);
      expect(isRacyLevel(null), isFalse);
      expect(isRacyLevel(''), isFalse);
      expect(isRacyLevel('UNKNOWN'), isFalse);
    });
  });

  group('wrapAvatarBlur', () {
    test('blur off → ίδιο child', () {
      const child = CircleAvatar();
      expect(
        wrapAvatarBlur(blurOn: false, racyLevel: 'VERY_LIKELY', child: child),
        same(child),
      );
    });

    test('sigma<=0 → ίδιο child', () {
      const child = CircleAvatar();
      expect(
        wrapAvatarBlur(
            blurOn: true, racyLevel: 'LIKELY', sigma: 0, child: child),
        same(child),
      );
    });

    test('non-racy level → ίδιο child', () {
      const child = CircleAvatar();
      expect(
        wrapAvatarBlur(
            blurOn: true, racyLevel: 'VERY_UNLIKELY', child: child),
        same(child),
      );
    });

    test('blur on + racy → ImageFiltered', () {
      const child = CircleAvatar();
      final wrapped = wrapAvatarBlur(
          blurOn: true, racyLevel: 'POSSIBLE', sigma: 12, child: child);
      expect(wrapped, isA<ImageFiltered>());
    });
  });
}
