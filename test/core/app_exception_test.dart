import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';

void main() {
  group('AppException.toFriendlyMessage', () {
    test('TimeoutException maps to chat/network-error (C6)', () {
      expect(
        AppException.toFriendlyMessage(TimeoutException('took too long')),
        'chat/network-error',
      );
    });

    test('AppException returns its code', () {
      const e = AppException(message: 'x', code: 'chat/network-error');
      expect(AppException.toFriendlyMessage(e), 'chat/network-error');
    });

    test('bilingual AppException message is returned as-is', () {
      const e = AppException(message: 'Σφάλμα δικτύου. Δοκίμασε ξανά. / Try again.',
          code: 'something');
      expect(
        AppException.toFriendlyMessage(e),
        'Σφάλμα δικτύου. Δοκίμασε ξανά. / Try again.',
      );
    });

    test('unknown error falls back to domain/unknown-error', () {
      expect(
        AppException.toFriendlyMessage(StateError('odd')),
        'unknown/unknown-error',
      );
    });

    test('known auth pattern maps to its code', () {
      expect(
        AppException.toFriendlyMessage(StateError('email-already-in-use')),
        'auth/email-already-in-use',
      );
    });
  });
}
