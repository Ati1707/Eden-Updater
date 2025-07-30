import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_update_service.dart';
import '../../platform_factory.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';

class LinuxUpdateService implements IPlatformUpdateService {
  final PreferencesService _preferencesService;

  LinuxUpdateService(this._preferencesService);

  @override
  List<String> getSupportedChannels() {
    final config = PlatformFactory.getCurrentPlatformConfig();
    return List.unmodifiable(config.supportedChannels);
  }

  @override
  bool isChannelSupported(String channel) {
    final config = PlatformFactory.getCurrentPlatformConfig();
    return config.supportedChannels.contains(channel.toLowerCase());
  }

  @override
  Future<Map<String, String>?> getInstallationMetadata(String channel) async {
    // Linux could store desktop file information or AppImage metadata
    try {
      final metadataString = await _preferencesService.getString(
        'linux_install_metadata_$channel',
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
      LoggingService.error('Failed to get Linux installation metadata', e);
      return null;
    }
  }

  @override
  Future<void> storeInstallationMetadata(
    String channel,
    Map<String, String> metadata,
  ) async {
    try {
      final metadataString = metadata.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('|');
      await _preferencesService.setString(
        'linux_install_metadata_$channel',
        metadataString,
      );
      LoggingService.info(
        'Stored Linux installation metadata for channel: $channel',
      );
    } catch (e) {
      LoggingService.error('Failed to store Linux installation metadata', e);
    }
  }

  @override
  Future<void> clearInstallationMetadata(String channel) async {
    try {
      await _preferencesService.remove('linux_install_metadata_$channel');
      LoggingService.info(
        'Cleared Linux installation metadata for channel: $channel',
      );
    } catch (e) {
      LoggingService.error('Failed to clear Linux installation metadata', e);
    }
  }

  @override
  Map<String, dynamic> getPlatformInfo() {
    return PlatformFactory.getPlatformInfo();
  }

  @override
  Future<void> cleanupTempFiles(
    String? tempDir,
    String? downloadedFilePath,
  ) async {
    try {
      // Clean up downloaded file
      if (downloadedFilePath != null) {
        final file = File(downloadedFilePath);
        if (await file.exists()) {
          await file.delete();
          LoggingService.info(
            'Cleaned up downloaded file: $downloadedFilePath',
          );
        }
      }

      // Clean up temp directory
      if (tempDir != null) {
        final dir = Directory(tempDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          LoggingService.info('Cleaned up temp directory: $tempDir');
        }
      }

      // Clean up any orphaned Eden temp directories
      final systemTempDir = Directory.systemTemp;
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          if (name.startsWith('eden_updater_') ||
              name.startsWith('eden_extract_')) {
            try {
              await entity.delete(recursive: true);
              LoggingService.info(
                'Cleaned up orphaned temp directory: ${entity.path}',
              );
            } catch (e) {
              LoggingService.warning(
                'Failed to clean up temp directory: ${entity.path}',
                e,
              );
            }
          }
        }
      }
    } catch (e) {
      LoggingService.warning('Failed to cleanup temp files on Linux', e);
    }
  }
}
