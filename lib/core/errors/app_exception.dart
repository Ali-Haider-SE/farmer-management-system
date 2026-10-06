class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() {
    if (code != null) {
      return 'AppException [$code]: $message';
    }

    return 'AppException: $message';
  }
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});
}

class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.code});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}
