/// Base class for application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;
}

/// Exception thrown when network operations fail
class NetworkException extends AppException {
  const NetworkException(super.message, [super.details]);
}

/// Exception thrown when file operations fail
class FileException extends AppException {
  const FileException(super.message, [super.details]);
}

/// Exception thrown when update operations fail
class UpdateException extends AppException {
  const UpdateException(super.message, [super.details]);
}

/// Exception thrown when Eden launcher operations fail
class LauncherException extends AppException {
  const LauncherException(super.message, [super.details]);
}

/// Exception thrown when archive extraction fails
class ExtractionException extends AppException {
  const ExtractionException(super.message, [super.details]);
}
