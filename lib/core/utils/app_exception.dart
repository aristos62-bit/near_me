class AppException implements Exception {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code = 'unknown',
    this.originalError,
    this.stackTrace,
  });

  AppException.database(
    String operation,
    Object error, [
    StackTrace? stack,
  ]) : this(
          message: 'Database error during $operation',
          code: 'database_error',
          originalError: error,
          stackTrace: stack,
        );

  AppException.firestore(
    String operation,
    Object error, [
    StackTrace? stack,
  ]) : this(
          message: 'Firestore error during $operation',
          code: 'firestore_error',
          originalError: error,
          stackTrace: stack,
        );

  AppException.auth(
    String operation,
    String message, [
    Object? originalError,
    StackTrace? stackTrace,
  ]) : this(
          message: message,
          code: 'auth_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  AppException.storage(
    String operation,
    Object error, [
    StackTrace? stack,
  ]) : this(
          message: 'Storage error during $operation',
          code: 'storage_error',
          originalError: error,
          stackTrace: stack,
        );

  AppException.network(
    String operation,
    Object error, [
    StackTrace? stack,
  ]) : this(
          message: 'Network error during $operation',
          code: 'network_error',
          originalError: error,
          stackTrace: stack,
        );

  AppException.validation(String field)
      : this(
          message: 'Validation failed for $field',
          code: 'validation_error',
        );

  @override
  String toString() => 'AppException($code): $message';
}
