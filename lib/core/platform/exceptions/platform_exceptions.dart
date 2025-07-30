import '../../errors/app_exceptions.dart';

/// Exception thrown when a platform is not supported
class PlatformNotSupportedException extends AppException {
  /// The unsupported platform name
  final String platform;

  PlatformNotSupportedException(this.platform)
    : super(
        'Platform not supported: $platform',
        'This platform is not currently supported by Eden Updater. '
            'Supported platforms are Windows, Linux, and Android.',
      );

  @override
  String toString() => 'PlatformNotSupportedException: $platform';
}

/// Exception thrown when a platform-specific operation fails
class PlatformOperationException extends AppException {
  /// The platform where the operation failed
  final String platform;

  /// The operation that failed
  final String operation;

  PlatformOperationException(this.platform, this.operation, String details)
    : super('Platform operation failed: $operation on $platform', details);

  @override
  String toString() =>
      'PlatformOperationException: $operation failed on $platform - $details';
}

/// Exception thrown when a file type is not supported by the current platform
class UnsupportedFileTypeException extends AppException {
  /// The unsupported file extension
  final String fileExtension;

  /// The current platform
  final String platform;

  UnsupportedFileTypeException(this.fileExtension, this.platform)
    : super(
        'Unsupported file type: $fileExtension on $platform',
        'The file type $fileExtension is not supported on $platform. '
            'Please check that you have downloaded the correct file for your platform.',
      );

  @override
  String toString() =>
      'UnsupportedFileTypeException: $fileExtension not supported on $platform';
}

/// Exception thrown when platform installation fails
class PlatformInstallationException extends AppException {
  /// The platform where installation failed
  final String platform;

  /// The file that failed to install
  final String filePath;

  PlatformInstallationException(this.platform, this.filePath, String details)
    : super(
        'Installation failed on $platform',
        'Failed to install $filePath: $details',
      );

  @override
  String toString() =>
      'PlatformInstallationException: Installation failed on $platform - $details';
}

/// Exception thrown when platform launcher operations fail
class PlatformLauncherException extends AppException {
  /// The platform where the launcher operation failed
  final String platform;

  /// The launcher operation that failed
  final String operation;

  PlatformLauncherException(this.platform, this.operation, String details)
    : super('Launcher operation failed: $operation on $platform', details);

  @override
  String toString() =>
      'PlatformLauncherException: $operation failed on $platform - $details';
}

/// Exception thrown when platform file operations fail
class PlatformFileException extends AppException {
  /// The platform where the file operation failed
  final String platform;

  /// The file operation that failed
  final String operation;

  /// The file path involved in the operation
  final String filePath;

  PlatformFileException(
    this.platform,
    this.operation,
    this.filePath,
    String details,
  ) : super(
        'File operation failed: $operation on $platform',
        'Failed to $operation file $filePath: $details',
      );

  @override
  String toString() =>
      'PlatformFileException: $operation failed on $platform for $filePath - $details';
}

/// Exception thrown when platform version detection fails
class PlatformVersionException extends AppException {
  /// The platform where version detection failed
  final String platform;

  /// The channel for which version detection failed
  final String channel;

  PlatformVersionException(this.platform, this.channel, String details)
    : super(
        'Version detection failed on $platform',
        'Failed to detect version for $channel channel: $details',
      );

  @override
  String toString() =>
      'PlatformVersionException: Version detection failed on $platform for $channel - $details';
}
