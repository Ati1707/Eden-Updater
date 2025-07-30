import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_file_handler.dart';
import '../../../services/logging_service.dart';

/// Linux-specific file handler implementation
class LinuxFileHandler implements IPlatformFileHandler {
  @override
  bool isEdenExecutable(String filename) {
    final name = filename.toLowerCase();

    // On Linux, Eden executables can have various names
    // Check for exact matches first
    if (name == 'eden' || name == 'eden-stable' || name == 'eden-nightly') {
      return true;
    }

    // Check for files that contain 'eden' but don't have extensions
    // (Linux executables typically don't have extensions)
    if (name.contains('eden') && !name.contains('.')) {
      return true;
    }

    // Check for AppImage files
    if (name.contains('eden') && name.endsWith('.appimage')) {
      return true;
    }

    return false;
  }

  @override
  String getEdenExecutablePath(String installPath, String? channel) {
    // On Linux, use channel-specific naming for better organization
    if (channel != null) {
      final fileName = channel == 'nightly' ? 'eden-nightly' : 'eden-stable';
      return path.join(installPath, fileName);
    } else {
      // Default to generic 'eden' if no channel specified
      return path.join(installPath, 'eden');
    }
  }

  @override
  Future<void> makeExecutable(String filePath) async {
    LoggingService.info('Making file executable on Linux: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.warning(
          'File does not exist, cannot make executable: $filePath',
        );
        return;
      }

      // Use chmod to add executable permissions
      final chmodResult = await Process.run('chmod', ['+x', filePath]);
      if (chmodResult.exitCode != 0) {
        LoggingService.error(
          'Failed to set executable permissions: ${chmodResult.stderr}',
        );
        throw Exception('chmod command failed: ${chmodResult.stderr}');
      }

      LoggingService.info('File is now executable: $filePath');

      // Verify the permissions were set correctly
      await _verifyExecutablePermissions(filePath);
    } catch (e) {
      LoggingService.error('Error making file executable on Linux', e);
      rethrow;
    }
  }

  @override
  Future<bool> containsEdenFiles(String folderPath) async {
    LoggingService.info(
      'Checking if Linux folder contains Eden files: $folderPath',
    );

    try {
      final dir = Directory(folderPath);

      if (!await dir.exists()) {
        LoggingService.warning('Directory does not exist: $folderPath');
        return false;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final filename = path.basename(entity.path).toLowerCase();

          // Check for the main executable
          if (isEdenExecutable(filename)) {
            LoggingService.info(
              'Found Eden executable in folder: ${entity.path}',
            );
            return true;
          }

          // Check for other characteristic files of the emulator distribution
          if (filename.contains('eden')) {
            // Look for common Eden-related files
            if (filename.contains('platforms') ||
                filename.contains('imageformats') ||
                filename.contains('bearer') ||
                filename.endsWith('.so') && filename.contains('qt')) {
              LoggingService.info(
                'Found Eden-related file in folder: ${entity.path}',
              );
              return true;
            }
          }

          // Check for Qt-related shared libraries which are common in Eden distributions
          if (filename.startsWith('libqt') && filename.endsWith('.so')) {
            LoggingService.info(
              'Found Qt shared library in folder (likely Eden): ${entity.path}',
            );
            return true;
          }

          // Check for other common Linux executable patterns
          if (filename.startsWith('qt') && filename.endsWith('.so')) {
            LoggingService.info(
              'Found Qt library in folder (likely Eden): ${entity.path}',
            );
            return true;
          }
        }
      }

      LoggingService.info('No Eden files found in folder: $folderPath');
      return false;
    } catch (e) {
      LoggingService.error(
        'Error checking if Linux folder contains Eden files',
        e,
      );
      return false;
    }
  }

  /// Verify that executable permissions were set correctly
  Future<void> _verifyExecutablePermissions(String filePath) async {
    try {
      // Use stat to check file permissions
      final statResult = await Process.run('stat', ['-c', '%a', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.info('File permissions after chmod: $permissions');

        // Check if the file has execute permissions (should contain 1, 3, 5, or 7 in any position)
        final hasExecutePermission =
            permissions.contains('1') ||
            permissions.contains('3') ||
            permissions.contains('5') ||
            permissions.contains('7');

        if (!hasExecutePermission) {
          LoggingService.warning(
            'File may not have proper execute permissions: $permissions',
          );
        } else {
          LoggingService.info(
            'File has proper execute permissions: $permissions',
          );
        }
      } else {
        LoggingService.warning(
          'Could not verify file permissions: ${statResult.stderr}',
        );
      }
    } catch (e) {
      LoggingService.warning('Error verifying executable permissions', e);
      // Don't throw as this is just verification
    }
  }

  /// Check if a file is executable by testing its permissions
  Future<bool> isFileExecutable(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      // Use stat to check if file has execute permissions
      final statResult = await Process.run('stat', ['-c', '%a', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();

        // Check if any position has execute permission (1, 3, 5, or 7)
        return permissions.contains('1') ||
            permissions.contains('3') ||
            permissions.contains('5') ||
            permissions.contains('7');
      }

      return false;
    } catch (e) {
      LoggingService.error('Error checking if file is executable', e);
      return false;
    }
  }

  /// Get file permissions in human-readable format
  Future<String?> getFilePermissions(String filePath) async {
    try {
      final statResult = await Process.run('stat', ['-c', '%A', filePath]);
      if (statResult.exitCode == 0) {
        return statResult.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      LoggingService.error('Error getting file permissions', e);
      return null;
    }
  }

  /// Set specific file permissions using chmod
  Future<void> setFilePermissions(String filePath, String permissions) async {
    try {
      LoggingService.info(
        'Setting file permissions: $filePath -> $permissions',
      );

      final chmodResult = await Process.run('chmod', [permissions, filePath]);
      if (chmodResult.exitCode != 0) {
        LoggingService.error(
          'Failed to set file permissions: ${chmodResult.stderr}',
        );
        throw Exception('chmod command failed: ${chmodResult.stderr}');
      }

      LoggingService.info('File permissions set successfully: $filePath');
    } catch (e) {
      LoggingService.error('Error setting file permissions', e);
      rethrow;
    }
  }

  /// Check if a file has the executable bit set
  Future<bool> hasExecutablePermission(String filePath) async {
    try {
      final statResult = await Process.run('stat', ['-c', '%a', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        // Check if any position has execute permission (1, 3, 5, or 7)
        return permissions.contains('1') ||
            permissions.contains('3') ||
            permissions.contains('5') ||
            permissions.contains('7');
      }
      return false;
    } catch (e) {
      LoggingService.error('Error checking executable permission', e);
      return false;
    }
  }

  /// Get the MIME type of a file using the file command
  Future<String?> getFileMimeType(String filePath) async {
    try {
      final result = await Process.run('file', ['--mime-type', '-b', filePath]);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      LoggingService.info('Could not determine MIME type for $filePath: $e');
      return null;
    }
  }

  /// Validate that a file is a valid AppImage
  Future<bool> isValidAppImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Check if it's executable
      if (!await hasExecutablePermission(filePath)) {
        LoggingService.info('AppImage file is not executable: $filePath');
        return false;
      }

      // Check MIME type
      final mimeType = await getFileMimeType(filePath);
      if (mimeType != null && !mimeType.contains('executable')) {
        LoggingService.info('AppImage has unexpected MIME type: $mimeType');
        return false;
      }

      return true;
    } catch (e) {
      LoggingService.error('Error validating AppImage', e);
      return false;
    }
  }
}
