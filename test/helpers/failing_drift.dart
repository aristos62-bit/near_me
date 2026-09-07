import 'package:drift/drift.dart';
import 'package:mocktail/mocktail.dart';

class MockQueryExecutor extends Mock implements QueryExecutor {}

/// [SPoT] QueryExecutor που αποτυγχάνει σε κάθε SQL query — για τα Drift
/// error-paths (`AppException.database`) των repositories.
QueryExecutor failingDriftExecutor() {
  final exec = MockQueryExecutor();
  when(() => exec.runSelect(any(), any()))
      .thenThrow(Exception('db failure'));
  when(() => exec.runInsert(any(), any()))
      .thenThrow(Exception('db failure'));
  when(() => exec.runUpdate(any(), any()))
      .thenThrow(Exception('db failure'));
  when(() => exec.runDelete(any(), any()))
      .thenThrow(Exception('db failure'));
  return exec;
}

/// Καλείται σε setUpAll πριν χρησιμοποιηθεί το [failingDriftExecutor].
void registerDriftFallbacks() {
  registerFallbackValue('');
  registerFallbackValue(<Object?>[]);
  registerFallbackValue(<String, Object?>{});
}