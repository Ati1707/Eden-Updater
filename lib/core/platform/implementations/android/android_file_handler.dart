import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../services/logging_service.dart';
import '../../interfaces/i_platform_file_handler.dart';

/// Android-specific file handler implementation
///
/// Handles APK detection, Android path handling, and Android-specific
/// directory operations and file access.
class AndroidFileHandler implements IPlatformFileHandler {
  @override
  bool isEdenExecutable(String filename) {
    // On Android, Eden comes as an APK file
    final name = filename.toLowerCase();

    // Check for APK files that contain "eden" in the name
    if (name.endsWith('.apk') && name.contains('eden')) {
      return true;
    }

    // Also check for common Eden APK naming patterns
    return name == 'eden.apk' ||
        name == 'eden-stable.apk' ||
        name == 'eden-nightly.apk' ||
        name == 'eden_emulator.apk' ||
        name.startsWith('eden') && name.endsWith('.apk');
  }

  @override
  String getEdenExecutablePath(String installPath, String? channel) {
    // On Android, there's no traditional executable path
    // Instead, we return the expected APK filename pattern
    if (channel != null) {
      switch (channel.toLowerCase()) {
        case 'nightly':
          return path.join(installPath, 'eden-nightly.apk');
        case 'stable':
        default:
          return path.join(installPath, 'eden-stable.apk');
      }
    }

    // Default to generic Eden APK name
    return path.join(installPath, 'eden.apk');
  }

  @override
  Future<void> makeExecutable(String filePath) async {
    // On Android, APK files don't need to be made executable
    // The Android system handles APK permissions
    LoggingService.info('makeExecutable not applicable for Android APK files');
  }

  @override
  Future<bool> containsEdenFiles(String folderPath) async {
    try {
      final dir = Directory(folderPath);

      if (!await dir.exists()) {
        return false;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final filename = path.basename(entity.path).toLowerCase();

          // Check for APK files
          if (isEdenExecutable(filename)) {
            LoggingService.info('Found Eden APK file: ${entity.path}');
            return true;
          }

          // Check for other characteristic Android files
          if (_isAndroidRelatedFile(filename)) {
            LoggingService.info(
              'Found Android-related Eden file: ${entity.path}',
            );
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      LoggingService.warning(
        'Error checking for Eden files in Android folder: $e',
      );
      return false;
    }
  }

  /// Checks if a filename represents an Android-related Eden file
  bool _isAndroidRelatedFile(String filename) {
    final name = filename.toLowerCase();

    // Check for Android-specific files that might be part of Eden distribution
    return (name.contains('eden') && name.endsWith('.apk')) ||
        (name.contains('android') && name.contains('eden')) ||
        (name == 'androidmanifest.xml' && _isInEdenContext(name)) ||
        (name.endsWith('.dex') && name.contains('eden')) ||
        (name.endsWith('.so') && name.contains('eden'));
  }

  /// Checks if a file is in an Eden-related context
  bool _isInEdenContext(String filename) {
    // This is a simplified check - in a full implementation,
    // we might check the parent directory structure or file contents
    return filename.toLowerCase().contains('eden');
  }

  /// Checks if a file is an APK file based on its signature
  Future<bool> isApkFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      // Check file extension first
      final extension = path.extension(filePath).toLowerCase();
      if (extension == '.apk') {
        return true;
      }

      // Check file signature (APK files are ZIP files with specific structure)
      final bytes = await file.openRead(0, 4).first;

      // ZIP file signature: 0x504B0304 (PK..)
      if (bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
          (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08)) {
        // For APK files, we should also check for AndroidManifest.xml
        // but for simplicity, we'll rely on the ZIP signature and extension
        return extension == '.apk';
      }

      return false;
    } catch (e) {
      LoggingService.warning('Error checking if file is APK: $e');
      return false;
    }
  }

  /// Gets the Android Downloads directory path
  String getDownloadsPath() {
    return '/storage/emulated/0/Download';
  }

  /// Gets the Android external storage path
  String getExternalStoragePath() {
    return '/storage/emulated/0';
  }

  /// Gets the Android app-specific external files directory
  /// Note: This would typically use path_provider in a real implementation
  String getAppExternalFilesPath() {
    return '/storage/emulated/0/Android/data/com.example.eden_updater/files';
  }

  /// Checks if external storage is available and writable
  Future<bool> isExternalStorageWritable() async {
    try {
      final externalDir = Directory(getExternalStoragePath());
      return await externalDir.exists();
    } catch (e) {
      LoggingService.warning('Error checking external storage: $e');
      return false;
    }
  }

  /// Creates Android-specific directory structure if needed
  Future<void> ensureAndroidDirectories() async {
    try {
      final appFilesDir = Directory(getAppExternalFilesPath());
      if (!await appFilesDir.exists()) {
        await appFilesDir.create(recursive: true);
        LoggingService.info('Created Android app files directory');
      }
    } catch (e) {
      LoggingService.warning('Error creating Android directories: $e');
    }
  }
}
