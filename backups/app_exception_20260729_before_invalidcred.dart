import '../debug/debug_config.dart';

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

  /// Μετατρέπει κάθε [error] object σε standardized error code.
  ///
  /// 1. AppException → code ή message (αν bilingual)
  /// 2. Γνωστά string patterns (auth, chat, search)
  /// 3. Fallback: `$domain/unknown-error` + DebugConfig.warn
  static String toFriendlyMessage(Object error, {String domain = 'unknown'}) {
    if (error is AppException) {
      if (error.message.contains(' / ')) {
        DebugConfig.log(DebugConfig.errorHandler,
            'AppException.toFriendlyMessage: bilingual → "${error.message}"');
        return error.message;
      }
      DebugConfig.log(DebugConfig.errorHandler,
          'AppException.toFriendlyMessage: code → "${error.code}"');
      return error.code;
    }

    final raw = error.toString();

    if (raw.contains('email-already-in-use')) return 'auth/email-already-in-use';
    if (raw.contains('invalid-email')) return 'auth/invalid-email';
    if (raw.contains('weak-password')) return 'auth/weak-password';
    if (raw.contains('user-not-found')) return 'auth/user-not-found';
    if (raw.contains('wrong-password')) return 'auth/wrong-password';
    if (raw.contains('too-many-requests')) return 'auth/too-many-requests';
    if (raw.contains('network-request-failed')) return 'auth/network-error';

    if (raw.contains('encryption_key_missing')) return 'chat/encryption-error';
    if (raw.contains('firestore_error') || raw.contains('Firestore')) {
      return 'chat/network-error';
    }

    if (raw.contains('permission-denied')) return 'search/permission-denied';

    DebugConfig.warn(
        'AppException.toFriendlyMessage: unhandled — $raw (domain: $domain)');
    return '$domain/unknown-error';
  }
}
