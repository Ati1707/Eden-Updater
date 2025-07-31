import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_file_handler.dart';
import '../../../services/logging_service.dart';

/// macOS-specific file handler implementation
class MacOSFileHandler implements IPlatformFileHandler {
  @override
  bool isEdenExecutable(String filename) {
    final name = filename.toLowerCase();

    // On macOS, Eden can be distributed as:
    // 1. .app bundle (Eden.app)
    // 2. Unix executable (eden, eden-stable, eden-nightly)
    // 3. Inside .app bundle (Eden.app/Contents/MacOS/Eden)

    // Check for .app bundles
    if (name.endsWith('.app') && name.contains('eden')) {
      return true;
    }

    // Check for Unix executables (no extension)
    if ((name == 'eden' || name == 'eden-stable' || name == 'eden-nightly') &&
        !name.contains('.')) {
      return true;
    }

    // Check for executables inside .app bundles
    if (name.contains('eden') &&
        !name.contains('.') &&
        filename.contains('Contents/MacOS/')) {
      return true;
    }

    return false;
  }

  @override
  String getEdenExecutablePath(String installPath, String? channel) {
    // On macOS, prefer .app bundle structure
    if (channel != null) {
      final appName = channel == 'nightly' ? 'Eden-Nightly.app' : 'Eden.app';
      final appPath = path.join(installPath, appName);

      // Check if .app bundle exists, return the executable inside it
      final executablePath = path.join(appPath, 'Contents', 'MacOS', 'Eden');
      return executablePath;
    } else {
      // Default to generic Eden.app
      return path.join(installPath, 'Eden.app', 'Contents', 'MacOS', 'Eden');
    }
  }

  @override
  Future<void> makeExecutable(String filePath) async {
    LoggingService.info('Making file executable on macOS: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.warning(
          'File does not exist, cannot make executable: $filePath',
        );
        return;
      }

      // Use chmod to add executable permissions (same as Linux)
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
      LoggingService.error('Error making file executable on macOS', e);
      rethrow;
    }
  }

  @override
  Future<bool> containsEdenFiles(String folderPath) async {
    LoggingService.info(
      'Checking if macOS folder contains Eden files: $folderPath',
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

          // Check for .app bundle structure
          if (entity.path.contains('.app') && filename.contains('eden')) {
            LoggingService.info(
              'Found Eden .app bundle in folder: ${entity.path}',
            );
            return true;
          }

          // Check for macOS-specific files
          if (filename.contains('eden')) {
            // Look for common macOS app files
            if (filename == 'info.plist' ||
                filename == 'pkginfo' ||
                filename.endsWith('.icns') ||
                filename.contains('frameworks')) {
              LoggingService.info(
                'Found Eden-related macOS file in folder: ${entity.path}',
              );
              return true;
            }
          }

          // Check for Qt frameworks which are common in Eden distributions
          if (filename.contains('qt') && filename.endsWith('.framework')) {
            LoggingService.info(
              'Found Qt framework in folder (likely Eden): ${entity.path}',
            );
            return true;
          }

          // Check for dylib files (macOS shared libraries)
          if (filename.startsWith('libqt') && filename.endsWith('.dylib')) {
            LoggingService.info(
              'Found Qt dylib in folder (likely Eden): ${entity.path}',
            );
            return true;
          }
        } else if (entity is Directory) {
          final dirname = path.basename(entity.path).toLowerCase();

          // Check for .app bundle directories
          if (dirname.endsWith('.app') && dirname.contains('eden')) {
            LoggingService.info(
              'Found Eden .app bundle directory: ${entity.path}',
            );
            return true;
          }

          // Check for Frameworks directory (common in macOS apps)
          if (dirname == 'frameworks' || dirname.endsWith('.framework')) {
            LoggingService.info(
              'Found Frameworks directory (likely Eden): ${entity.path}',
            );
            return true;
          }
        }
      }

      LoggingService.info('No Eden files found in folder: $folderPath');
      return false;
    } catch (e) {
      LoggingService.error(
        'Error checking if macOS folder contains Eden files',
        e,
      );
      return false;
    }
  }

  /// Verify that executable permissions were set correctly
  Future<void> _verifyExecutablePermissions(String filePath) async {
    try {
      // Use stat to check file permissions (same as Linux)
      final statResult = await Process.run('stat', ['-f', '%A', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.info('File permissions after chmod: $permissions');

        // Check if the file has execute permissions
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

      // Use stat to check if file has execute permissions (macOS format)
      final statResult = await Process.run('stat', ['-f', '%A', filePath]);
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
      final statResult = await Process.run('stat', ['-f', '%Sp', filePath]);
      if (statResult.exitCode == 0) {
        return statResult.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      LoggingService.error('Error getting file permissions', e);
      return null;
    }
  }

  /// Check if a path is a valid .app bundle
  Future<bool> isValidAppBundle(String appPath) async {
    try {
      final appDir = Directory(appPath);
      if (!await appDir.exists() || !appPath.endsWith('.app')) {
        return false;
      }

      // Check for required .app bundle structure
      final contentsDir = Directory(path.join(appPath, 'Contents'));
      final macosDir = Directory(path.join(appPath, 'Contents', 'MacOS'));
      final infoPlist = File(path.join(appPath, 'Contents', 'Info.plist'));

      return await contentsDir.exists() &&
          await macosDir.exists() &&
          await infoPlist.exists();
    } catch (e) {
      LoggingService.error('Error validating .app bundle', e);
      return false;
    }
  }

  /// Get the main executable path from a .app bundle
  Future<String?> getAppBundleExecutable(String appPath) async {
    try {
      if (!await isValidAppBundle(appPath)) {
        return null;
      }

      final macosDir = Directory(path.join(appPath, 'Contents', 'MacOS'));

      // Look for Eden executable in MacOS directory
      await for (final entity in macosDir.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          if (isEdenExecutable(filename)) {
            return entity.path;
          }
        }
      }

      return null;
    } catch (e) {
      LoggingService.error('Error getting app bundle executable', e);
      return null;
    }
  }

  /// Check if a file is a DMG disk image
  bool isDMGFile(String filePath) {
    return filePath.toLowerCase().endsWith('.dmg');
  }

  /// Check if a file is a ZIP archive
  bool isZipFile(String filePath) {
    return filePath.toLowerCase().endsWith('.zip');
  }

  /// Get the file type using the `file` command
  Future<String?> getFileType(String filePath) async {
    try {
      final result = await Process.run('file', ['-b', filePath]);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      LoggingService.info('Could not determine file type for $filePath: $e');
      return null;
    }
  }
}
