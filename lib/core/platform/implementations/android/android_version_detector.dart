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

      LoggingService.info(
        'No Android installation found for channel: $channel',
      );
      return null;
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
}
