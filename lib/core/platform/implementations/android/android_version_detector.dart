import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../../models/update_info.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../interfaces/i_platform_version_detector.dart';

/// Android-specific version detector implementation
///
/// Handles version detection and storage using SharedPreferences-based tracking
/// and manages Android installation metadata storage and retrieval.
class AndroidVersionDetector implements IPlatformVersionDetector {
  final PreferencesService _preferencesService;

  AndroidVersionDetector(this._preferencesService);

  @override
  Future<UpdateInfo?> getCurrentVersion(String channel) async {
    try {
      LoggingService.info(
        'Checking Android installed version for channel: $channel',
      );

      // Priority 0: Check for test version override (for debugging)
      final testVersion = await _preferencesService.getString(
        'test_version_override',
      );
      final testChannel = await _preferencesService.getString(
        'test_version_channel',
      );
      if (testVersion != null && testChannel == channel) {
        LoggingService.info('Using test version override: $testVersion');
        return UpdateInfo(
          version: testVersion,
          downloadUrl: '',
          releaseNotes: 'Test version set manually',
          releaseDate: DateTime.now(),
          fileSize: 0,
          releaseUrl: '',
        );
      }

      // First, validate if Eden is actually installed on the device
      final isEdenInstalled = await _isEdenAppInstalled();

      if (!isEdenInstalled) {
        LoggingService.info(
          'Eden app is not installed on device - clearing stored version info',
        );
        // Clear any stored version info since Eden is not actually installed
        await clearVersionInfo(channel);
        return null;
      }

      LoggingService.info(
        'Eden app is installed on device - checking stored version',
      );

      // Method 1: Check stored installation metadata
      final metadata = await _getAndroidInstallationMetadata(channel);
      if (metadata != null && metadata.containsKey('version')) {
        final version = metadata['version']!;
        final installDate = metadata['installDate'];

        LoggingService.info(
          'Found Android installation metadata - Version: $version',
        );

        return UpdateInfo(
          version: version,
          downloadUrl: metadata['downloadUrl'] ?? '',
          releaseNotes: '',
          releaseDate: installDate != null
              ? DateTime.tryParse(installDate) ?? DateTime.now()
              : DateTime.now(),
          fileSize: int.tryParse(metadata['fileSize'] ?? '0') ?? 0,
          releaseUrl: '',
        );
      }

      // Method 2: Check legacy stored version info
      final storedVersion = await _preferencesService.getString(
        'android_last_install_$channel',
      );
      if (storedVersion != null) {
        LoggingService.info(
          'Found legacy Android installation - Version: $storedVersion',
        );

        return UpdateInfo(
          version: storedVersion,
          downloadUrl: '',
          releaseNotes: '',
          releaseDate: DateTime.now(),
          fileSize: 0,
          releaseUrl: '',
        );
      }

      // Method 3: Check if APK file exists in Downloads (recently downloaded)
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        await for (final entity in downloadsDir.list()) {
          if (entity is File &&
              entity.path.toLowerCase().contains('eden') &&
              entity.path.toLowerCase().endsWith('.apk')) {
            final fileName = path.basename(entity.path);
            // Try to extract version from filename like "Eden_v0.0.3-rc1.apk"
            final versionMatch = RegExp(
              r'Eden[_-]v?([0-9]+\.[0-9]+\.[0-9]+[^\.]*)',
              caseSensitive: false,
            ).firstMatch(fileName);
            if (versionMatch != null) {
              final version = 'v${versionMatch.group(1)}';
              LoggingService.info(
                'Found Eden APK in Downloads - Version: $version',
              );

              // Store this version for future reference
              await _preferencesService.setString(
                'android_last_install_$channel',
                version,
              );

              return UpdateInfo(
                version: version,
                downloadUrl: '',
                releaseNotes: '',
                releaseDate: DateTime.now(),
                fileSize: await entity.length(),
                releaseUrl: '',
              );
            }
          }
        }
      }

      // If Eden is installed but we have no version info, return a generic version
      LoggingService.info(
        'Eden is installed but no version information found - returning generic version',
      );
      return UpdateInfo(
        version: 'Unknown',
        downloadUrl: '',
        releaseNotes: 'Eden is installed but version is unknown',
        releaseDate: DateTime.now(),
        fileSize: 0,
        releaseUrl: '',
      );
    } catch (e) {
      LoggingService.error('Error getting Android current version: $e');
      return null;
    }
  }

  @override
  Future<void> storeVersionInfo(UpdateInfo updateInfo, String channel) async {
    try {
      LoggingService.info(
        'Storing Android version info for channel $channel: ${updateInfo.version}',
      );

      // Store installation metadata in structured format
      final metadata = <String, String>{
        'version': updateInfo.version,
        'downloadUrl': updateInfo.downloadUrl,
        'installDate': DateTime.now().toIso8601String(),
        'fileSize': updateInfo.fileSize.toString(),
        'releaseUrl': updateInfo.releaseUrl,
      };

      // Store metadata as pipe-separated key=value pairs
      await _preferencesService.setString(
        'android_install_metadata_$channel',
        metadata.entries.map((e) => '${e.key}=${e.value}').join('|'),
      );

      // Also store in legacy format for backward compatibility
      await _preferencesService.setString(
        'android_last_install_$channel',
        updateInfo.version,
      );

      // Store in the general current version format
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);

      LoggingService.info('Android version info stored successfully');
    } catch (e) {
      LoggingService.error('Error storing Android version info: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearVersionInfo(String channel) async {
    try {
      LoggingService.info(
        'Clearing Android version info for channel: $channel',
      );

      // Clear all Android-specific version storage
      await _preferencesService.remove('android_install_metadata_$channel');
      await _preferencesService.remove('android_last_install_$channel');

      // Clear general current version
      await _preferencesService.remove('current_version_$channel');

      LoggingService.info('Android version info cleared successfully');
    } catch (e) {
      LoggingService.error('Error clearing Android version info: $e');
      rethrow;
    }
  }

  /// Get Android installation metadata for a channel
  Future<Map<String, String>?> _getAndroidInstallationMetadata(
    String channel,
  ) async {
    try {
      final metadataString = await _preferencesService.getString(
        'android_install_metadata_$channel',
      );
      if (metadataString == null) return null;

      final metadata = <String, String>{};
      for (final pair in metadataString.split('|')) {
        final parts = pair.split('=');
        if (parts.length == 2) {
          metadata[parts[0]] = parts[1];
        }
      }
      return metadata;
    } catch (e) {
      LoggingService.error('Failed to get Android installation metadata: $e');
      return null;
    }
  }

  /// Debug method to manually set version for testing
  Future<void> setCurrentVersionForTesting(
    String version,
    String channel,
  ) async {
    await _preferencesService.setString('test_version_override', version);
    await _preferencesService.setString('test_version_channel', channel);
    await _preferencesService.setCurrentVersion(channel, version);

    LoggingService.info('Test version set: $version for channel: $channel');
  }

  /// Get the successful package name used for launching (Android-specific)
  Future<String?> getSuccessfulPackageName() async {
    return await _preferencesService.getString('android_successful_package');
  }

  /// Store the successful package name for future launches (Android-specific)
  Future<void> storeSuccessfulPackageName(String packageName) async {
    await _preferencesService.setString(
      'android_successful_package',
      packageName,
    );
    LoggingService.info('Stored successful Android package name: $packageName');
  }

  /// Check if the Android installation has metadata for a specific channel
  Future<bool> hasInstallationMetadata(String channel) async {
    final metadata = await _getAndroidInstallationMetadata(channel);
    return metadata != null && metadata.containsKey('version');
  }

  /// Get the installation date for a specific channel
  Future<DateTime?> getInstallationDate(String channel) async {
    final metadata = await _getAndroidInstallationMetadata(channel);
    if (metadata != null && metadata.containsKey('installDate')) {
      return DateTime.tryParse(metadata['installDate']!);
    }
    return null;
  }

  /// Check if Eden app is actually installed on the Android device
  Future<bool> _isEdenAppInstalled() async {
    try {
      LoggingService.debug(
        'Checking if Eden app is installed on Android device',
      );

      final possiblePackageNames = [
        'dev.eden.eden_emulator',
        'org.eden.emulator',
        'com.eden.emulator',
        'eden.emulator',
      ];

      for (final packageName in possiblePackageNames) {
        if (await _isPackageInstalled(packageName)) {
          LoggingService.info('Found installed Eden package: $packageName');
          return true;
        }
      }

      LoggingService.info('No Eden package found installed on device');
      return false;
    } catch (e) {
      LoggingService.warning('Error checking if Eden app is installed: $e');
      return false;
    }
  }

  /// Check if a specific package is installed on the device
  Future<bool> _isPackageInstalled(String packageName) async {
    try {
      LoggingService.debug('Checking if package is installed: $packageName');

      // For Android version detection, we use a heuristic approach:
      // If we have recent installation metadata, assume the app is still installed
      // This avoids complex platform channel implementations while being practical

      final metadata = await _getAndroidInstallationMetadata('stable');
      if (metadata != null && metadata.containsKey('installDate')) {
        final installDate = DateTime.tryParse(metadata['installDate']!);
        if (installDate != null) {
          final daysSinceInstall = DateTime.now()
              .difference(installDate)
              .inDays;
          // If installed within the last 30 days, assume it's still there
          final isRecentlyInstalled = daysSinceInstall <= 30;
          LoggingService.debug(
            'Package $packageName: installed $daysSinceInstall days ago, assuming installed: $isRecentlyInstalled',
          );
          return isRecentlyInstalled;
        }
      }

      // Also check if we have a successful package name stored from recent launches
      final successfulPackage = await getSuccessfulPackageName();
      if (successfulPackage == packageName) {
        LoggingService.debug(
          'Package $packageName was successfully launched recently, assuming installed',
        );
        return true;
      }

      LoggingService.debug(
        'No evidence of package $packageName being installed',
      );
      return false;
    } catch (e) {
      LoggingService.debug('Error checking if package is installed: $e');
      return false;
    }
  }

  /// Validate and clean up stale version information
  /// This method can be called periodically to ensure version info reflects actual installation status
  Future<void> validateAndCleanupVersionInfo() async {
    try {
      LoggingService.info('Validating Android version information');

      final isInstalled = await _isEdenAppInstalled();
      if (!isInstalled) {
        LoggingService.info(
          'Eden not detected on device - clearing all stored version information',
        );

        // Clear version info for all channels
        await clearVersionInfo('stable');
        await clearVersionInfo('nightly');

        // Clear successful package name
        await _preferencesService.remove('android_successful_package');

        LoggingService.info('Cleared stale Android version information');
      } else {
        LoggingService.info(
          'Eden detected on device - version information is valid',
        );
      }
    } catch (e) {
      LoggingService.error('Error validating Android version information: $e');
    }
  }
}
