import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/timeouts.dart';

void main() {
  group('withTimeout', () {
    test('returns value when future completes before the timeout', () async {
      final result = await withTimeout(
        Future.value(42),
        'test.op',
        timeout: const Duration(seconds: 5),
      );
      expect(result, 42);
    });

    test('propagates an error from the inner future', () async {
      expect(
        () => withTimeout(
          Future<int>.error(StateError('boom')),
          'test.op',
          timeout: const Duration(seconds: 5),
        ),
        throwsStateError,
      );
    });

    test('throws TimeoutException when future does not complete in time',
        () async {
      final completer = Completer<int>();
      final future = withTimeout(
        completer.future,
        'test.op',
        timeout: const Duration(milliseconds: 100),
      );
      await expectLater(future, throwsA(isA<TimeoutException>()));
      // Κατανάλωσε το late completion για να μην καταλήξει σε unhandled error.
      completer.complete(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('late completion after timeout is consumed without a crash',
        () async {
      final completer = Completer<int>();
      var timedOut = false;
      try {
        await withTimeout(
          completer.future,
          'test.op',
          timeout: const Duration(milliseconds: 50),
        );
      } on TimeoutException {
        timedOut = true;
      }
      expect(timedOut, isTrue);

      // Ολοκληρώνουμε ΑΡΓΟΤΕΡΑ από το timeout — η late completion πρέπει να
      // καταναλωθεί αθόρυβα (unawaited + onError), χωρίς unhandled exception.
      completer.complete(99);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    test('late error after timeout is consumed without leaking an unhandled '
        'exception', () async {
      final completer = Completer<int>();
      try {
        await withTimeout(
          completer.future,
          'test.op',
          timeout: const Duration(milliseconds: 50),
        );
      } on TimeoutException {
        // αναμενόμενο
      }

      // Metro: το late ERROR πρέπει να περάσει από τον onError του unawaited.
      completer.completeError(StateError('late boom'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });
}
