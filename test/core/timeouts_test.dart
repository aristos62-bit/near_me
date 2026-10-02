import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
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

  group('throwTimeoutAs', () {
    test('throws AppException with search code + bilingual message', () {
      expect(
        () => throwTimeoutAs('search.geoFanOut', 'search/unknown-error'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'search/unknown-error')
            .having((e) => e.message, 'message', contains(' / '))),
      );
    });

    test('throws AppException with request code', () {
      expect(
        () => throwTimeoutAs('request.preChecks', 'request/send-failed'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'request/send-failed')),
      );
    });

    test('throws AppException with group code', () {
      expect(
        () => throwTimeoutAs('group.profileFetch', 'group/create-failed'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'group/create-failed')),
      );
    });

    test('throws AppException with chat network code (C6c writes)', () {
      expect(
        () => throwTimeoutAs('sendMessage.commit', 'chat/network-error'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'chat/network-error')
            .having((e) => e.message, 'message', contains(' / '))),
      );
    });

    test('throws AppException with chat delete code (C6c writes)', () {
      expect(
        () => throwTimeoutAs('delete.preCheck', 'chat/delete-failed'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'chat/delete-failed')),
      );
    });

    test('throws AppException with chat unknown code (C6c clear)', () {
      expect(
        () => throwTimeoutAs('clear.preCheck', 'chat/unknown-error'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'chat/unknown-error')),
      );
    });

    test('bilingual message passes through toFriendlyMessage as-is', () {
      AppException? caught;
      try {
        throwTimeoutAs('search.geoFanOut', 'search/unknown-error');
      } on AppException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(AppException.toFriendlyMessage(caught, domain: 'search'),
          contains(' / '));
    });
  });
}
