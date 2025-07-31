import 'dart:io';
import '../../interfaces/i_platform_update_service.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';

/// macOS-specific update service implementation
class MacOSUpdateService implements IPlatformUpdateService {
  final PreferencesService _preferencesService;

  MacOSUpdateService(this._preferencesService);

  @override
  bool isChannelSupported(String channel) {
    LoggingService.debug('[macOS] Checking if channel is supported: $channel');

    // macOS supports both stable and nightly channels
    final supportedChannels = ['stable', 'nightly'];
    final isSupported = supportedChannels.contains(channel.toLowerCase());

    LoggingService.debug('[macOS] Channel $channel supported: $isSupported');
    return isSupported;
  }

  @override
  List<String> getSupportedChannels() {
    LoggingService.debug('[macOS] Getting supported channels');

    const channels = ['stable', 'nightly'];
    LoggingService.debug('[macOS] Supported channels: $channels');

    return channels;
  }

  @override
  Future<Map<String, String>?> getInstallationMetadata(String channel) async {
    LoggingService.debug('[macOS] Getting installation metadata for: $channel');

    try {
      final key = 'macos_installation_metadata_$channel';
      final metadataJson = await _preferencesService.getString(key);

      if (metadataJson != null) {
        // Parse JSON string back to Map
        final Map<String, dynamic> parsed = {};
        // Simple parsing for key=value pairs
        for (final pair in metadataJson.split(',')) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            parsed[parts[0]] = parts[1];
          }
        }
        return Map<String, String>.from(parsed);
      }

      return null;
    } catch (e) {
      LoggingService.error('[macOS] Error getting installation metadata', e);
      return null;
    }
  }

  @override
  Future<void> storeInstallationMetadata(
    String channel,
    Map<String, String> metadata,
  ) async {
    LoggingService.debug('[macOS] Storing installation metadata for: $channel');

    try {
      final key = 'macos_installation_metadata_$channel';
      // Simple serialization to string
      final metadataString = metadata.entries
          .map((e) => '${e.key}=${e.value}')
          .join(',');

      await _preferencesService.setString(key, metadataString);
      LoggingService.debug('[macOS] Installation metadata stored successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error storing installation metadata', e);
      rethrow;
    }
  }

  @override
  Future<void> clearInstallationMetadata(String channel) async {
    LoggingService.debug(
      '[macOS] Clearing installation metadata for: $channel',
    );

    try {
      final key = 'macos_installation_metadata_$channel';
      await _preferencesService.remove(key);
      LoggingService.debug(
        '[macOS] Installation metadata cleared successfully',
      );
    } catch (e) {
      LoggingService.error('[macOS] Error clearing installation metadata', e);
      rethrow;
    }
  }

  @override
  Map<String, dynamic> getPlatformInfo() {
    LoggingService.debug('[macOS] Getting platform information');

    return {
      'platform': 'macOS',
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'supportedChannels': ['stable', 'nightly'],
      'supportedFileTypes': ['.dmg', '.app', '.zip', '.tar.gz'],
      'supportsAutoUpdate': true,
      'supportsPortableMode': true,
      'supportsShortcuts': true,
      'requiresExecutablePermissions': true,
    };
  }

  @override
  Future<void> cleanupTempFiles(
    String? tempDir,
    String? downloadedFilePath,
  ) async {
    LoggingService.debug('[macOS] Cleaning up temporary files');

    try {
      // Clean up temp directory if provided
      if (tempDir != null) {
        final tempDirectory = Directory(tempDir);
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
          LoggingService.debug('[macOS] Cleaned up temp directory: $tempDir');
        }
      }

      // Clean up downloaded file if provided
      if (downloadedFilePath != null) {
        final downloadedFile = File(downloadedFilePath);
        if (await downloadedFile.exists()) {
          await downloadedFile.delete();
          LoggingService.debug(
            '[macOS] Cleaned up downloaded file: $downloadedFilePath',
          );
        }
      }

      LoggingService.debug('[macOS] Temporary files cleanup completed');
    } catch (e) {
      LoggingService.error('[macOS] Error cleaning up temporary files', e);
      // Don't rethrow as cleanup is not critical
    }
  }
}
