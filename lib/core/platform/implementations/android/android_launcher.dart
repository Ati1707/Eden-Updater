import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../../../services/logging_service.dart';
import '../../../utils/url_launcher_utils.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../interfaces/i_platform_launcher.dart';
import '../../exceptions/platform_exceptions.dart';

/// Android-specific launcher implementation
///
/// Handles launching Eden emulator on Android using package manager
/// and intent-based launching with fallback mechanisms.
class AndroidLauncher implements IPlatformLauncher {
  final PreferencesService _preferencesService;

  AndroidLauncher(this._preferencesService);

  @override
  Future<void> launchEden() async {
    try {
      LoggingService.info('Attempting to launch Eden on Android');

      // Get the channel to check if we have installation metadata
      final channel = await _preferencesService.getReleaseChannel();

      // Check if we have stored installation metadata
      final metadataString = await _preferencesService.getString(
        'android_install_metadata_$channel',
      );
      if (metadataString == null) {
        LoggingService.warning(
          'No Android installation metadata found for channel: $channel',
        );
        throw PlatformOperationException(
          'Android',
          'launch',
          'Eden not found. No Eden installation detected. Please install Eden first.',
        );
      }

      // Try to launch Eden using the correct package name
      final possiblePackageNames = [
        // Correct Eden package name
        'dev.eden.eden_emulator',
        // Fallback variations just in case
        'org.eden.emulator',
        'com.eden.emulator',
        'eden.emulator',
      ];

      bool launched = false;
      String? successfulPackage;

      for (final packageName in possiblePackageNames) {
        try {
          LoggingService.info('Trying to launch package: $packageName');

          // Method 1: Try using url_launcher with app-specific URI
          if (await _tryLaunchWithUrlLauncher(packageName)) {
            LoggingService.info(
              'Successfully launched Eden Android app via url_launcher: $packageName',
            );
            successfulPackage = packageName;
            launched = true;
            break;
          }

          // Method 2: Try using Android Intent directly
          if (await _tryLaunchWithIntent(packageName)) {
            LoggingService.info(
              'Successfully launched Eden Android app via Intent: $packageName',
            );
            successfulPackage = packageName;
            launched = true;
            break;
          }
        } catch (e) {
          LoggingService.info('All launch methods failed for $packageName: $e');
          // Try next package name
          continue;
        }
      }

      if (!launched) {
        LoggingService.warning(
          'Could not launch Eden Android app - no matching package found',
        );

        // Try alternative launch method - open the APK file directly
        await _tryLaunchFromApkFile();
      } else if (successfulPackage != null) {
        // Store the successful package name for future launches
        await _preferencesService.setString(
          'android_successful_package',
          successfulPackage,
        );
      }
    } catch (e) {
      LoggingService.error('Failed to launch Eden on Android: $e');
      if (e is PlatformOperationException) {
        rethrow;
      }
      throw PlatformOperationException(
        'Android',
        'launch',
        'Failed to launch Eden: $e',
      );
    }
  }

  @override
  Future<void> createDesktopShortcut() async {
    // Android doesn't support desktop shortcuts in the traditional sense
    // The system handles app shortcuts through the launcher
    LoggingService.info('Desktop shortcuts not applicable on Android platform');
  }

  @override
  Future<String?> findEdenExecutable(String installPath, String channel) async {
    // On Android, there's no traditional executable file
    // Instead, we check if the app is installed via package manager
    try {
      final possiblePackageNames = [
        'dev.eden.eden_emulator',
        'org.eden.emulator',
        'com.eden.emulator',
        'eden.emulator',
      ];

      for (final packageName in possiblePackageNames) {
        if (await _isPackageInstalled(packageName)) {
          LoggingService.info('Found installed Eden package: $packageName');
          return packageName; // Return package name instead of file path
        }
      }

      LoggingService.info('No Eden package found installed');
      return null;
    } catch (e) {
      LoggingService.warning('Error finding Eden executable on Android: $e');
      return null;
    }
  }

  /// Try to launch the app using url_launcher
  Future<bool> _tryLaunchWithUrlLauncher(String packageName) async {
    try {
      // Method 1: Try using url_launcher with app-specific URI
      LoggingService.info('Trying url_launcher for package: $packageName');
      if (packageName == 'dev.eden.eden_emulator') {
        final appUri = 'android-app://dev.eden.eden_emulator';
        final success = await UrlLauncherUtils.launchUrlRobust(appUri);
        if (success) {
          LoggingService.info('Successfully launched app URI for $packageName');
          return true;
        }
      }

      // Fallback to package URI
      final packageUri = 'package:$packageName';
      final success = await UrlLauncherUtils.launchUrlRobust(packageUri);
      if (success) {
        LoggingService.info(
          'Successfully launched package URI for $packageName',
        );
        return true;
      }
    } catch (e) {
      LoggingService.info('url_launcher failed for $packageName: $e');
    }
    return false;
  }

  /// Try to launch the app using Android Intent
  Future<bool> _tryLaunchWithIntent(String packageName) async {
    try {
      LoggingService.info('Trying Android Intent for $packageName');

      // Create launch intent for the package
      AndroidIntent intent;

      // Try to launch the app using its launch intent
      if (packageName == 'dev.eden.eden_emulator') {
        // Use a more direct approach for Eden
        intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'dev.eden.eden_emulator',
          flags: <int>[
            0x10000000, // FLAG_ACTIVITY_NEW_TASK
            0x00000020, // FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
          ],
        );
      } else {
        // Generic launcher intent for fallback packages
        intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: packageName,
          category: 'android.intent.category.LAUNCHER',
          flags: <int>[
            0x10000000, // FLAG_ACTIVITY_NEW_TASK
            0x00000020, // FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
          ],
        );
      }

      await intent.launch();
      return true;
    } catch (e) {
      LoggingService.info('Android Intent failed for $packageName: $e');
      return false;
    }
  }

  /// Try to launch Eden by opening the APK file from Downloads
  Future<void> _tryLaunchFromApkFile() async {
    try {
      LoggingService.info('Trying to launch Eden from APK file');

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        await for (final entity in downloadsDir.list()) {
          if (entity is File &&
              entity.path.toLowerCase().contains('eden') &&
              entity.path.toLowerCase().endsWith('.apk')) {
            LoggingService.info('Found Eden APK: ${entity.path}');

            // Try to open the APK file (this will show the app info or launch it)
            final fileUri = 'file://${entity.path}';
            final success = await UrlLauncherUtils.launchUrlRobust(fileUri);

            if (success) {
              LoggingService.info('Opened Eden APK file');
              return;
            }
          }
        }
      }

      // If we get here, we couldn't find or launch the APK
      throw PlatformOperationException(
        'Android',
        'launch',
        'Eden appears to be installed but cannot be launched. '
            'Please check your app drawer for "Eden" or try reinstalling.',
      );
    } catch (e) {
      LoggingService.error('Failed to launch Eden from APK file: $e');
      throw PlatformOperationException(
        'Android',
        'launch',
        'Could not launch Eden. Please check if Eden is properly installed and try launching it manually from your app drawer.',
      );
    }
  }

  /// Check if a package is installed on the device
  Future<bool> _isPackageInstalled(String packageName) async {
    try {
      // Try to create a launch intent for the package
      // If it succeeds, the package is likely installed
      final uri = Uri.parse('package:$packageName');
      return await canLaunchUrl(uri);
    } catch (e) {
      LoggingService.info('Error checking if package is installed: $e');
      return false;
    }
  }
}
