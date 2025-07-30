import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:path/path.dart' as path;

import '../../../../models/update_info.dart';
import '../../../services/logging_service.dart';
import '../../interfaces/i_platform_installer.dart';
import '../../exceptions/platform_exceptions.dart';

/// Android-specific installer implementation
///
/// Handles APK installation using Android Intents and manages
/// Android-specific file storage and installation metadata.
class AndroidInstaller implements IPlatformInstaller {
  @override
  Future<bool> canHandle(String filePath) async {
    return await _isApkFile(filePath);
  }

  @override
  Future<void> install(
    String filePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      LoggingService.info('[Android] Starting installation operation');
      LoggingService.info('[Android] File path: $filePath');
      LoggingService.info('[Android] Update version: ${updateInfo.version}');
      LoggingService.info(
        '[Android] Create shortcuts: $createShortcuts (not applicable)',
      );
      LoggingService.info(
        '[Android] Portable mode: $portableMode (not applicable)',
      );
      LoggingService.debug(
        '[Android] Platform: Android ${Platform.operatingSystemVersion}',
      );

      onStatusUpdate('Installing APK...');
      onProgress(0.1);

      // Verify this is an APK file
      LoggingService.debug('[Android] Verifying APK file format...');
      if (!await canHandle(filePath)) {
        LoggingService.error('[Android] File is not a valid APK: $filePath');
        throw PlatformOperationException(
          'Android',
          'install',
          'File is not a valid APK: $filePath',
        );
      }

      onProgress(0.3);
      onStatusUpdate('Launching APK installer...');

      // Use Android Intent to launch the APK installer
      LoggingService.debug('[Android] Launching system APK installer...');
      await _installAndroidApk(filePath, onProgress, onStatusUpdate);

      onProgress(1.0);
      onStatusUpdate('APK installation initiated');

      LoggingService.info(
        '[Android] Installation operation completed successfully',
      );
    } catch (e) {
      LoggingService.error('[Android] Installation operation failed: $e');
      if (e is PlatformOperationException) {
        rethrow;
      }
      throw PlatformOperationException(
        'Android',
        'install',
        'Failed to install APK: $e',
      );
    }
  }

  @override
  Future<void> postInstallSetup(
    String installPath,
    UpdateInfo updateInfo,
  ) async {
    // Android APK installation doesn't require post-install setup
    // The Android system handles the installation process
    LoggingService.info('[Android] Performing post-install setup');
    LoggingService.debug(
      '[Android] Install path: $installPath (not used on Android)',
    );
    LoggingService.debug('[Android] Update version: ${updateInfo.version}');
    LoggingService.info(
      '[Android] Post-install setup completed (no action required - system handles APK installation)',
    );
  }

  /// Checks if the given file is an APK file
  Future<bool> _isApkFile(String filePath) async {
    try {
      LoggingService.debug('[Android] Checking if file is APK: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('[Android] File does not exist: $filePath');
        return false;
      }

      // Check file extension
      final extension = path.extension(filePath).toLowerCase();
      LoggingService.debug('[Android] File extension: $extension');

      if (extension == '.apk') {
        LoggingService.debug('[Android] File has .apk extension');
        return true;
      }

      // Check file signature (APK files are ZIP files with specific structure)
      LoggingService.debug('[Android] Checking file signature...');
      final bytes = await file.openRead(0, 4).first;

      // ZIP file signature: 0x504B0304 (PK..)
      if (bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
          (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08)) {
        LoggingService.debug(
          '[Android] File has ZIP signature, checking for APK structure...',
        );
        // Additional check: APK files should have AndroidManifest.xml
        // This is a more thorough check but requires ZIP parsing
        // For now, we'll rely on the ZIP signature and extension
        return extension == '.apk' || await _hasAndroidManifest(filePath);
      }

      LoggingService.debug('[Android] File is not an APK');
      return false;
    } catch (e) {
      LoggingService.warning('[Android] Error checking if file is APK: $e');
      return false;
    }
  }

  /// Checks if the ZIP/APK file contains AndroidManifest.xml
  Future<bool> _hasAndroidManifest(String filePath) async {
    try {
      // This is a simplified check - in a full implementation,
      // we would parse the ZIP file to look for AndroidManifest.xml
      // For now, we'll assume files with .apk extension are APK files
      return path.extension(filePath).toLowerCase() == '.apk';
    } catch (e) {
      LoggingService.warning('Error checking for AndroidManifest: $e');
      return false;
    }
  }

  /// Installs an Android APK using Android Intent
  Future<void> _installAndroidApk(
    String filePath,
    Function(double) onProgress,
    Function(String) onStatusUpdate,
  ) async {
    try {
      LoggingService.info(
        '[Android] Launching APK installer using Android Intent',
      );
      LoggingService.debug('[Android] APK file path: $filePath');
      onProgress(0.5);

      // Try multiple intent approaches for better compatibility
      bool launched = false;

      // Method 1: Standard APK installation intent
      LoggingService.debug(
        '[Android] Attempting Method 1: Standard APK installation intent',
      );
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'file://$filePath',
          type: 'application/vnd.android.package-archive',
          flags: [
            0x10000000, // FLAG_ACTIVITY_NEW_TASK
            0x00000001, // FLAG_GRANT_READ_URI_PERMISSION
          ],
        );

        onStatusUpdate('Opening system installer...');
        onProgress(0.7);

        await intent.launch();
        launched = true;
        LoggingService.info(
          '[Android] APK installer launched via standard intent',
        );
      } catch (e) {
        LoggingService.warning('[Android] Standard APK intent failed: $e');
      }

      // Method 2: Alternative intent with different flags
      if (!launched) {
        LoggingService.debug(
          '[Android] Attempting Method 2: Alternative intent with different flags',
        );
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.INSTALL_PACKAGE',
            data: 'file://$filePath',
            type: 'application/vnd.android.package-archive',
            flags: [
              0x10000000, // FLAG_ACTIVITY_NEW_TASK
              0x00000002, // FLAG_GRANT_WRITE_URI_PERMISSION
              0x00000001, // FLAG_GRANT_READ_URI_PERMISSION
            ],
          );

          onStatusUpdate('Trying alternative installer...');
          onProgress(0.8);

          await intent.launch();
          launched = true;
          LoggingService.info(
            '[Android] APK installer launched via alternative intent',
          );
        } catch (e) {
          LoggingService.warning('[Android] Alternative APK intent failed: $e');
        }
      }

      // Method 3: Generic file viewer intent
      if (!launched) {
        LoggingService.debug(
          '[Android] Attempting Method 3: Generic file viewer intent',
        );
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'file://$filePath',
            flags: [0x10000000], // FLAG_ACTIVITY_NEW_TASK
          );

          onStatusUpdate('Opening with file viewer...');
          onProgress(0.85);

          await intent.launch();
          launched = true;
          LoggingService.info(
            '[Android] APK installer launched via file viewer intent',
          );
        } catch (e) {
          LoggingService.warning('[Android] File viewer intent failed: $e');
        }
      }

      if (!launched) {
        LoggingService.error('[Android] All APK installation methods failed');
        throw PlatformOperationException(
          'Android',
          'installApk',
          'All APK installation methods failed. Please install the APK manually from: $filePath',
        );
      }

      onProgress(0.9);
      onStatusUpdate('Installation handed off to system');

      LoggingService.info('[Android] APK installer launched successfully');
    } catch (e) {
      LoggingService.error('[Android] Failed to launch APK installer: $e');
      if (e is PlatformOperationException) {
        rethrow;
      }
      throw PlatformOperationException(
        'Android',
        'installApk',
        'Failed to launch APK installer: $e',
      );
    }
  }
}
