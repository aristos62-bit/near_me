import 'dart:async';
import '../debug/debug_config.dart';

/// SPoT για futures με timeout + ασφαλή κατανάλωση του late completion.
///
/// ΠΟΤΕ `.catchError` χωρίς return → runtime TypeError σε non-nullable T
/// (AGENTS.md). Το late completion του "εγκαταλελειμμένου" future μετά το
/// timeout καταναλώνεται με unawaited + onError. Ίδιο pattern με το
/// `FirebaseInit.tryInitialize`, τα `StorageHelpers` και τα CF rate-limit calls.
Future<T> withTimeout<T>(
  Future<T> f,
  String op, {
  Duration timeout = const Duration(seconds: 8),
}) {
  var timedOut = false;
  unawaited(f.then<void>((_) {},
      onError: (Object e) {
        if (timedOut) {
          DebugConfig.warn('$op: late completion after timeout', data: e);
        }
      }));
  return f.timeout(timeout, onTimeout: () {
    timedOut = true;
    DebugConfig.warn('$op: timed out after ${timeout.inSeconds}s');
    throw TimeoutException('$op: timeout after ${timeout.inSeconds}s', timeout);
  });
}
