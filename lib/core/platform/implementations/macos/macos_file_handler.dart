import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_file_handler.dart';
import '../../../services/logging_service.dart';

/// macOS-specific file handler implementation
class MacOSFileHandler implements IPlatformFileHandler {
  @override
  bool isEdenExecutable(String filename) {
    try {
      final name = filename.toLowerCase();
      final originalPath = filename;

      // On macOS, Eden can be distributed as:
      // 1. .app bundle (Eden.app)
      // 2. Unix executable (eden, eden-stable, eden-nightly)
      // 3. Inside .app bundle (Eden.app/Contents/MacOS/Eden)

      // Check for .app bundles
      if (name.endsWith('.app') && name.contains('eden')) {
        LoggingService.debug('Detected Eden .app bundle: $filename');
        return true;
      }

      // Check for Unix executables (no extension)
      if ((name == 'eden' || name == 'eden-stable' || name == 'eden-nightly') &&
          !name.contains('.')) {
        LoggingService.debug('Detected Eden Unix executable: $filename');
        return true;
      }

      // Check for executables inside .app bundles
      if (name.contains('eden') &&
          !name.contains('.') &&
          originalPath.contains('Contents/MacOS/')) {
        LoggingService.debug(
          'Detected Eden executable inside .app bundle: $filename',
        );
        return true;
      }

      // Additional checks for common Eden executable patterns
      if (name.startsWith('eden') && !name.contains('.')) {
        LoggingService.debug('Detected Eden executable with prefix: $filename');
        return true;
      }

      return false;
    } catch (e) {
      LoggingService.error(
        'Error checking if file is Eden executable: $filename',
        e,
      );
      return false;
    }
  }

  @override
  String getEdenExecutablePath(String installPath, String? channel) {
    try {
      LoggingService.debug(
        'Getting Eden executable path for install: $installPath, channel: $channel',
      );

      // On macOS, prefer .app bundle structure
      if (channel != null) {
        final appName = channel == 'nightly' ? 'Eden-Nightly.app' : 'Eden.app';
        final appPath = path.join(installPath, appName);

        // Check if .app bundle exists, return the executable inside it
        final executablePath = path.join(appPath, 'Contents', 'MacOS', 'Eden');
        LoggingService.debug(
          'Generated .app bundle executable path: $executablePath',
        );
        return executablePath;
      } else {
        // Default to generic Eden.app
        final defaultPath = path.join(
          installPath,
          'Eden.app',
          'Contents',
          'MacOS',
          'Eden',
        );
        LoggingService.debug('Generated default executable path: $defaultPath');
        return defaultPath;
      }
    } catch (e) {
      LoggingService.error('Error generating Eden executable path', e);
      // Return a fallback path
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
        throw FileSystemException('File does not exist', filePath);
      }

      // Check if file is already executable
      if (await isFileExecutable(filePath)) {
        LoggingService.info('File is already executable: $filePath');
        return;
      }

      // Use chmod to add executable permissions for owner, group, and others
      final chmodResult = await Process.run('chmod', ['+x', filePath]);
      if (chmodResult.exitCode != 0) {
        final errorMsg = chmodResult.stderr.toString().trim();
        LoggingService.error('Failed to set executable permissions: $errorMsg');
        throw Exception('chmod command failed: $errorMsg');
      }

      LoggingService.info('Successfully set executable permissions: $filePath');

      // Verify the permissions were set correctly
      await _verifyExecutablePermissions(filePath);

      // Double-check that the file is now executable
      if (!await isFileExecutable(filePath)) {
        LoggingService.warning(
          'File may not be properly executable after chmod: $filePath',
        );
      }
    } catch (e) {
      LoggingService.error(
        'Error making file executable on macOS: $filePath',
        e,
      );
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

      var foundEdenFiles = false;
      var fileCount = 0;

      await for (final entity in dir.list(recursive: true)) {
        fileCount++;

        if (entity is File) {
          final filename = path.basename(entity.path).toLowerCase();
          final fullPath = entity.path;

          // Check for the main executable
          if (isEdenExecutable(filename)) {
            LoggingService.info('Found Eden executable in folder: $fullPath');
            foundEdenFiles = true;
            break;
          }

          // Check for .app bundle structure files
          if (fullPath.contains('.app') && filename.contains('eden')) {
            LoggingService.info(
              'Found Eden .app bundle file in folder: $fullPath',
            );
            foundEdenFiles = true;
            break;
          }

          // Check for macOS-specific files with Eden context
          if (filename.contains('eden') ||
              fullPath.toLowerCase().contains('eden')) {
            // Look for common macOS app files
            if (filename == 'info.plist' ||
                filename == 'pkginfo' ||
                filename.endsWith('.icns') ||
                filename.contains('frameworks')) {
              LoggingService.info(
                'Found Eden-related macOS file in folder: $fullPath',
              );
              foundEdenFiles = true;
              break;
            }
          }

          // Check for Qt frameworks which are common in Eden distributions
          if (filename.contains('qt') &&
              (filename.endsWith('.framework') ||
                  fullPath.contains('.framework'))) {
            LoggingService.info(
              'Found Qt framework in folder (likely Eden): $fullPath',
            );
            foundEdenFiles = true;
            break;
          }

          // Check for dylib files (macOS shared libraries)
          if (filename.startsWith('libqt') && filename.endsWith('.dylib')) {
            LoggingService.info(
              'Found Qt dylib in folder (likely Eden): $fullPath',
            );
            foundEdenFiles = true;
            break;
          }

          // Check for other common Eden-related files
          if (filename.startsWith('eden') ||
              filename.contains('emulator') ||
              (filename.contains('qt') && filename.endsWith('.dylib'))) {
            LoggingService.info('Found Eden-related file in folder: $fullPath');
            foundEdenFiles = true;
            break;
          }
        } else if (entity is Directory) {
          final dirname = path.basename(entity.path).toLowerCase();
          final fullPath = entity.path;

          // Check for .app bundle directories
          if (dirname.endsWith('.app') && dirname.contains('eden')) {
            LoggingService.info('Found Eden .app bundle directory: $fullPath');
            foundEdenFiles = true;
            break;
          }

          // Check for Frameworks directory (common in macOS apps)
          if (dirname == 'frameworks' || dirname.endsWith('.framework')) {
            // Only consider it Eden-related if it's in an Eden context
            if (fullPath.toLowerCase().contains('eden') ||
                fullPath.contains('.app')) {
              LoggingService.info(
                'Found Frameworks directory (likely Eden): $fullPath',
              );
              foundEdenFiles = true;
              break;
            }
          }

          // Check for Contents directory (part of .app bundle structure)
          if (dirname == 'contents' && fullPath.contains('.app')) {
            LoggingService.debug(
              'Found Contents directory in .app bundle: $fullPath',
            );
            // Continue checking for more specific files
          }
        }

        // Prevent infinite loops on very large directories
        if (fileCount > 10000) {
          LoggingService.warning(
            'Stopping file search after 10000 files in: $folderPath',
          );
          break;
        }
      }

      if (foundEdenFiles) {
        LoggingService.info('Eden files found in folder: $folderPath');
      } else {
        LoggingService.info(
          'No Eden files found in folder: $folderPath (checked $fileCount items)',
        );
      }

      return foundEdenFiles;
    } catch (e) {
      LoggingService.error(
        'Error checking if macOS folder contains Eden files: $folderPath',
        e,
      );
      return false;
    }
  }

  /// Verify that executable permissions were set correctly
  Future<void> _verifyExecutablePermissions(String filePath) async {
    try {
      // Use stat to check file permissions in octal format (macOS format)
      final statResult = await Process.run('stat', ['-f', '%A', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.info(
          'File permissions after chmod (octal): $permissions',
        );

        // Parse octal permissions to check execute bits
        if (permissions.length >= 3) {
          final ownerPerms =
              int.tryParse(
                permissions.substring(
                  permissions.length - 3,
                  permissions.length - 2,
                ),
              ) ??
              0;
          final groupPerms =
              int.tryParse(
                permissions.substring(
                  permissions.length - 2,
                  permissions.length - 1,
                ),
              ) ??
              0;
          final otherPerms =
              int.tryParse(permissions.substring(permissions.length - 1)) ?? 0;

          final ownerExecute = (ownerPerms & 1) != 0;
          final groupExecute = (groupPerms & 1) != 0;
          final otherExecute = (otherPerms & 1) != 0;

          LoggingService.debug(
            'Execute permissions - Owner: $ownerExecute, Group: $groupExecute, Other: $otherExecute',
          );

          if (!ownerExecute) {
            LoggingService.warning(
              'File does not have owner execute permission: $permissions',
            );
          } else {
            LoggingService.info(
              'File has proper execute permissions: $permissions',
            );
          }
        }

        // Also get human-readable permissions for logging
        final humanResult = await Process.run('stat', ['-f', '%Sp', filePath]);
        if (humanResult.exitCode == 0) {
          final humanPerms = humanResult.stdout.toString().trim();
          LoggingService.debug(
            'File permissions (human readable): $humanPerms',
          );
        }
      } else {
        final errorMsg = statResult.stderr.toString().trim();
        LoggingService.warning('Could not verify file permissions: $errorMsg');
      }
    } catch (e) {
      LoggingService.warning(
        'Error verifying executable permissions: $filePath',
        e,
      );
      // Don't throw as this is just verification
    }
  }

  /// Check if a file is executable by testing its permissions
  Future<bool> isFileExecutable(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('File does not exist, not executable: $filePath');
        return false;
      }

      // Use stat to check if file has execute permissions (macOS format)
      final statResult = await Process.run('stat', ['-f', '%A', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.debug(
          'Checking executable permissions for $filePath: $permissions',
        );

        // Parse octal permissions to check execute bits more accurately
        if (permissions.length >= 3) {
          final ownerPerms =
              int.tryParse(
                permissions.substring(
                  permissions.length - 3,
                  permissions.length - 2,
                ),
              ) ??
              0;
          final hasOwnerExecute = (ownerPerms & 1) != 0;

          LoggingService.debug(
            'Owner execute permission for $filePath: $hasOwnerExecute',
          );
          return hasOwnerExecute;
        }

        // Fallback: Check if any position has execute permission (1, 3, 5, or 7)
        final hasExecute =
            permissions.contains('1') ||
            permissions.contains('3') ||
            permissions.contains('5') ||
            permissions.contains('7');

        LoggingService.debug(
          'Fallback execute check for $filePath: $hasExecute',
        );
        return hasExecute;
      }

      LoggingService.warning('Could not check file permissions for: $filePath');
      return false;
    } catch (e) {
      LoggingService.error(
        'Error checking if file is executable: $filePath',
        e,
      );
      return false;
    }
  }

  /// Get file permissions in human-readable format
  Future<String?> getFilePermissions(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('File does not exist: $filePath');
        return null;
      }

      final statResult = await Process.run('stat', ['-f', '%Sp', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.debug('File permissions for $filePath: $permissions');
        return permissions;
      } else {
        LoggingService.warning(
          'Failed to get file permissions: ${statResult.stderr}',
        );
        return null;
      }
    } catch (e) {
      LoggingService.error('Error getting file permissions for: $filePath', e);
      return null;
    }
  }

  /// Get file permissions in octal format
  Future<String?> getFilePermissionsOctal(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('File does not exist: $filePath');
        return null;
      }

      final statResult = await Process.run('stat', ['-f', '%A', filePath]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.debug(
          'File permissions (octal) for $filePath: $permissions',
        );
        return permissions;
      } else {
        LoggingService.warning(
          'Failed to get octal file permissions: ${statResult.stderr}',
        );
        return null;
      }
    } catch (e) {
      LoggingService.error(
        'Error getting octal file permissions for: $filePath',
        e,
      );
      return null;
    }
  }

  /// Set specific file permissions using chmod
  Future<void> setFilePermissions(String filePath, String permissions) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File does not exist', filePath);
      }

      LoggingService.info(
        'Setting file permissions to $permissions for: $filePath',
      );

      final chmodResult = await Process.run('chmod', [permissions, filePath]);
      if (chmodResult.exitCode != 0) {
        final errorMsg = chmodResult.stderr.toString().trim();
        LoggingService.error('Failed to set file permissions: $errorMsg');
        throw Exception('chmod command failed: $errorMsg');
      }

      LoggingService.info(
        'Successfully set file permissions to $permissions for: $filePath',
      );

      // Verify the permissions were set
      await _verifyExecutablePermissions(filePath);
    } catch (e) {
      LoggingService.error('Error setting file permissions for: $filePath', e);
      rethrow;
    }
  }

  /// Validate that a file has the minimum required permissions for execution
  Future<bool> validateExecutablePermissions(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.warning(
          'Cannot validate permissions, file does not exist: $filePath',
        );
        return false;
      }

      // Check if file is executable
      final isExecutable = await isFileExecutable(filePath);
      if (!isExecutable) {
        LoggingService.warning('File is not executable: $filePath');
        return false;
      }

      // Check if file is readable (required for execution)
      final permissions = await getFilePermissionsOctal(filePath);
      if (permissions != null && permissions.length >= 3) {
        final ownerPerms =
            int.tryParse(
              permissions.substring(
                permissions.length - 3,
                permissions.length - 2,
              ),
            ) ??
            0;
        final hasOwnerRead = (ownerPerms & 4) != 0;

        if (!hasOwnerRead) {
          LoggingService.warning('File is not readable by owner: $filePath');
          return false;
        }
      }

      LoggingService.info('File has valid executable permissions: $filePath');
      return true;
    } catch (e) {
      LoggingService.error(
        'Error validating executable permissions for: $filePath',
        e,
      );
      return false;
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
    try {
      final name = filePath.toLowerCase();
      final isDmg = name.endsWith('.dmg');

      if (isDmg) {
        LoggingService.debug('Detected DMG file: $filePath');
      }

      return isDmg;
    } catch (e) {
      LoggingService.error('Error checking if file is DMG: $filePath', e);
      return false;
    }
  }

  /// Validate DMG file using hdiutil
  Future<bool> validateDMGFile(String filePath) async {
    try {
      if (!isDMGFile(filePath)) {
        LoggingService.debug('File is not a DMG: $filePath');
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.warning('DMG file does not exist: $filePath');
        return false;
      }

      LoggingService.info('Validating DMG file: $filePath');

      // Use hdiutil to verify the DMG
      final result = await Process.run('hdiutil', ['verify', filePath]);

      if (result.exitCode == 0) {
        LoggingService.info('DMG file is valid: $filePath');
        return true;
      } else {
        final errorMsg = result.stderr.toString().trim();
        LoggingService.warning('DMG validation failed: $errorMsg');
        return false;
      }
    } catch (e) {
      LoggingService.error('Error validating DMG file: $filePath', e);
      return false;
    }
  }

  /// Check if a file is a ZIP archive
  bool isZipFile(String filePath) {
    try {
      final name = filePath.toLowerCase();
      final isZip = name.endsWith('.zip');

      if (isZip) {
        LoggingService.debug('Detected ZIP file: $filePath');
      }

      return isZip;
    } catch (e) {
      LoggingService.error('Error checking if file is ZIP: $filePath', e);
      return false;
    }
  }

  /// Check if a file is a tar.gz archive
  bool isTarGzFile(String filePath) {
    try {
      final name = filePath.toLowerCase();
      final isTarGz = name.endsWith('.tar.gz') || name.endsWith('.tgz');

      if (isTarGz) {
        LoggingService.debug('Detected tar.gz file: $filePath');
      }

      return isTarGz;
    } catch (e) {
      LoggingService.error('Error checking if file is tar.gz: $filePath', e);
      return false;
    }
  }

  /// Check if a path is a framework directory
  bool isFrameworkDirectory(String dirPath) {
    try {
      final name = path.basename(dirPath).toLowerCase();
      final isFramework = name.endsWith('.framework');

      if (isFramework) {
        LoggingService.debug('Detected framework directory: $dirPath');
      }

      return isFramework;
    } catch (e) {
      LoggingService.error(
        'Error checking if directory is framework: $dirPath',
        e,
      );
      return false;
    }
  }

  /// Check if a file is a dylib (dynamic library)
  bool isDylibFile(String filePath) {
    try {
      final name = path.basename(filePath).toLowerCase();
      final isDylib = name.endsWith('.dylib');

      if (isDylib) {
        LoggingService.debug('Detected dylib file: $filePath');
      }

      return isDylib;
    } catch (e) {
      LoggingService.error('Error checking if file is dylib: $filePath', e);
      return false;
    }
  }

  /// Validate framework structure
  Future<bool> validateFrameworkStructure(String frameworkPath) async {
    try {
      if (!isFrameworkDirectory(frameworkPath)) {
        return false;
      }

      final frameworkDir = Directory(frameworkPath);
      if (!await frameworkDir.exists()) {
        LoggingService.warning(
          'Framework directory does not exist: $frameworkPath',
        );
        return false;
      }

      final frameworkName = path.basenameWithoutExtension(frameworkPath);

      // Check for required framework structure
      final mainBinary = File(path.join(frameworkPath, frameworkName));
      final versionsDir = Directory(path.join(frameworkPath, 'Versions'));

      final hasMainBinary = await mainBinary.exists();
      final hasVersionsDir = await versionsDir.exists();

      LoggingService.debug(
        'Framework validation for $frameworkPath - Binary: $hasMainBinary, Versions: $hasVersionsDir',
      );

      return hasMainBinary || hasVersionsDir; // At least one should exist
    } catch (e) {
      LoggingService.error(
        'Error validating framework structure: $frameworkPath',
        e,
      );
      return false;
    }
  }

  /// Get the file type using the `file` command
  Future<String?> getFileType(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug(
          'File does not exist for type detection: $filePath',
        );
        return null;
      }

      final result = await Process.run('file', ['-b', filePath]);
      if (result.exitCode == 0) {
        final fileType = result.stdout.toString().trim();
        LoggingService.debug('File type for $filePath: $fileType');
        return fileType;
      } else {
        LoggingService.warning('Failed to get file type: ${result.stderr}');
        return null;
      }
    } catch (e) {
      LoggingService.error('Error determining file type for: $filePath', e);
      return null;
    }
  }

  /// Get detailed file information using file command with MIME type
  Future<Map<String, String?>> getDetailedFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'exists': 'false'};
      }

      final results = <String, String?>{'exists': 'true'};

      // Get basic file type
      final typeResult = await Process.run('file', ['-b', filePath]);
      if (typeResult.exitCode == 0) {
        results['type'] = typeResult.stdout.toString().trim();
      }

      // Get MIME type
      final mimeResult = await Process.run('file', [
        '-b',
        '--mime-type',
        filePath,
      ]);
      if (mimeResult.exitCode == 0) {
        results['mime'] = mimeResult.stdout.toString().trim();
      }

      // Get file size
      final stat = await file.stat();
      results['size'] = stat.size.toString();

      LoggingService.debug('Detailed file info for $filePath: $results');
      return results;
    } catch (e) {
      LoggingService.error(
        'Error getting detailed file info for: $filePath',
        e,
      );
      return {'exists': 'false', 'error': e.toString()};
    }
  }

  /// Check if a file or directory is related to Eden emulator
  Future<bool> isEdenRelated(String itemPath) async {
    try {
      final name = path.basename(itemPath).toLowerCase();
      final fullPath = itemPath.toLowerCase();

      // Direct Eden references
      if (name.contains('eden') || fullPath.contains('eden')) {
        LoggingService.debug('Found Eden-related item by name: $itemPath');
        return true;
      }

      // Check if it's inside an Eden .app bundle
      if (fullPath.contains('eden.app') ||
          fullPath.contains('eden-nightly.app')) {
        LoggingService.debug('Found item inside Eden .app bundle: $itemPath');
        return true;
      }

      // Check for common Eden-related files
      if (name.contains('emulator') ||
          name.contains('qt') ||
          name.startsWith('lib') && name.contains('qt')) {
        LoggingService.debug('Found potentially Eden-related item: $itemPath');
        return true;
      }

      return false;
    } catch (e) {
      LoggingService.error(
        'Error checking if item is Eden-related: $itemPath',
        e,
      );
      return false;
    }
  }
}
