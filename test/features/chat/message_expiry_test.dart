import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/utils/message_expiry.dart';

void main() {
  group('MessageExpiry values', () {
    test('has 7 values in locked order', () {
      expect(MessageExpiry.values,
          ['off', '1min', '5min', '30min', '6h', '12h', '24h']);
    });

    test('off const matches first value', () {
      expect(MessageExpiry.off, 'off');
      expect(MessageExpiry.values.first, MessageExpiry.off);
    });
  });

  group('MessageExpiry.isValid', () {
    test('accepts all known values', () {
      for (final v in MessageExpiry.values) {
        expect(MessageExpiry.isValid(v), isTrue, reason: v);
      }
    });

    test('rejects unknown values', () {
      expect(MessageExpiry.isValid(''), isFalse);
      expect(MessageExpiry.isValid('7d'), isFalse);
      expect(MessageExpiry.isValid('OFF'), isFalse);
    });
  });

  group('MessageExpiry.durationFor', () {
    test('maps each value to duration', () {
      expect(MessageExpiry.durationFor('1min'), const Duration(minutes: 1));
      expect(MessageExpiry.durationFor('5min'), const Duration(minutes: 5));
      expect(MessageExpiry.durationFor('30min'), const Duration(minutes: 30));
      expect(MessageExpiry.durationFor('6h'), const Duration(hours: 6));
      expect(MessageExpiry.durationFor('12h'), const Duration(hours: 12));
      expect(MessageExpiry.durationFor('24h'), const Duration(hours: 24));
    });

    test('returns null for off and unknown', () {
      expect(MessageExpiry.durationFor('off'), isNull);
      expect(MessageExpiry.durationFor('7d'), isNull);
    });
  });

  group('MessageExpiry.display', () {
    test('greek labels', () {
      expect(MessageExpiry.display('1min', greek: true), '1 λεπτό');
      expect(MessageExpiry.display('5min', greek: true), '5 λεπτά');
      expect(MessageExpiry.display('30min', greek: true), '30 λεπτά');
      expect(MessageExpiry.display('6h', greek: true), '6 ώρες');
      expect(MessageExpiry.display('12h', greek: true), '12 ώρες');
      expect(MessageExpiry.display('24h', greek: true), '24 ώρες');
    });

    test('english labels', () {
      expect(MessageExpiry.display('1min', greek: false), '1 minute');
      expect(MessageExpiry.display('5min', greek: false), '5 minutes');
      expect(MessageExpiry.display('30min', greek: false), '30 minutes');
      expect(MessageExpiry.display('6h', greek: false), '6 hours');
      expect(MessageExpiry.display('12h', greek: false), '12 hours');
      expect(MessageExpiry.display('24h', greek: false), '24 hours');
    });

    test('returns empty for unknown', () {
      expect(MessageExpiry.display('7d', greek: true), '');
      expect(MessageExpiry.display('7d', greek: false), '');
    });
  });
}
