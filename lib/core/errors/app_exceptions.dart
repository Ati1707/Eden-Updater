import '../services/logging_service.dart';

/// Base class for application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;

  /// Log this exception with appropriate level
  void log([StackTrace? stackTrace]) {
    LoggingService.error(toString(), this, stackTrace);
  }
}

/// Exception thrown when network operations fail
class NetworkException extends AppException {
  NetworkException(super.message, [super.details]) {
    LoggingService.error('NetworkException: $message', details);
  }
}

/// Exception thrown when file operations fail
class FileException extends AppException {
  FileException(super.message, [super.details]) {
    LoggingService.error('FileException: $message', details);
  }
}

/// Exception thrown when update operations fail
class UpdateException extends AppException {
  UpdateException(super.message, [super.details]) {
    LoggingService.error('UpdateException: $message', details);
  }
}

/// Exception thrown when Eden launcher operations fail
class LauncherException extends AppException {
  LauncherException(super.message, [super.details]) {
    LoggingService.error('LauncherException: $message', details);
  }
}

/// Exception thrown when archive extraction fails
class ExtractionException extends AppException {
  ExtractionException(super.message, [super.details]) {
    LoggingService.error('ExtractionException: $message', details);
  }
}
