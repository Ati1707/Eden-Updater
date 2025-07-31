import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_installation_service.dart';
import '../../../services/logging_service.dart';
import '../../../errors/app_exceptions.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../interfaces/i_platform_file_handler.dart';

/// macOS-specific installation service implementation
class MacOSInstallationService implements IPlatformInstallationService {
  final IPlatformFileHandler _fileHandler;
  final PreferencesService _preferencesService;

  MacOSInstallationService(this._fileHandler, this._preferencesService);

  @override
  Future<String> getDefaultInstallPath() async {
    LoggingService.debug('[macOS] Getting default installation directory');

    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) {
        LoggingService.error('[macOS] HOME environment variable not found');
        throw UpdateException('HOME environment variable not found', '');
      }

      final defaultDir = path.join(homeDir, 'Documents', 'Eden');
      LoggingService.debug(
        '[macOS] Default installation directory: $defaultDir',
      );

      return defaultDir;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error getting default installation directory',
        e,
      );
      rethrow;
    }
  }

  @override
  String getChannelFolderName(String channel) {
    return channel == 'nightly' ? 'Eden-Nightly' : 'Eden-Release';
  }

  @override
  Future<void> organizeInstallation(String installPath, String channel) async {
    LoggingService.debug(
      '[macOS] Organizing installation for channel: $channel',
    );

    try {
      // For macOS, the installation is already organized during the install process
      // This method is mainly for compatibility with the interface
      LoggingService.debug('[macOS] Installation organization completed');
    } catch (e) {
      LoggingService.error('[macOS] Error organizing installation', e);
      rethrow;
    }
  }

  @override
  Future<void> scanAndStoreEdenExecutable(
    String installPath,
    String channel,
  ) async {
    LoggingService.debug('[macOS] Scanning and storing Eden executable');

    try {
      final edenPath = _fileHandler.getEdenExecutablePath(installPath, channel);

      if (await File(edenPath).exists()) {
        // Store the executable path in preferences
        await _preferencesService.setEdenExecutablePath(channel, edenPath);
        LoggingService.info('[macOS] Stored Eden executable path: $edenPath');
      } else {
        LoggingService.warning('[macOS] Eden executable not found: $edenPath');
      }
    } catch (e) {
      LoggingService.error(
        '[macOS] Error scanning and storing Eden executable',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> cleanEdenFolder(String edenPath) async {
    LoggingService.debug('[macOS] Cleaning Eden folder: $edenPath');

    try {
      final edenDir = Directory(edenPath);

      if (await edenDir.exists()) {
        // Remove all contents except user folder
        await for (final entity in edenDir.list()) {
          if (entity is Directory && path.basename(entity.path) == 'user') {
            // Skip user folder to preserve user data
            LoggingService.debug(
              '[macOS] Preserving user folder: ${entity.path}',
            );
            continue;
          }

          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
            LoggingService.debug('[macOS] Deleted: ${entity.path}');
          } catch (e) {
            LoggingService.warning(
              '[macOS] Could not delete: ${entity.path}',
              e,
            );
          }
        }

        LoggingService.debug('[macOS] Eden folder cleaned successfully');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error cleaning Eden folder', e);
      rethrow;
    }
  }

  @override
  Future<void> mergeEdenFolder(String sourcePath, String targetPath) async {
    LoggingService.debug(
      '[macOS] Merging Eden folder: $sourcePath -> $targetPath',
    );

    try {
      await copyDirectory(sourcePath, targetPath);
      LoggingService.debug('[macOS] Eden folder merged successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error merging Eden folder', e);
      rethrow;
    }
  }

  @override
  Future<void> copyDirectory(String sourcePath, String targetPath) async {
    LoggingService.debug(
      '[macOS] Copying directory: $sourcePath -> $targetPath',
    );

    try {
      // Use cp -R for efficient directory copying on macOS
      final result = await Process.run('cp', ['-R', sourcePath, targetPath]);

      if (result.exitCode != 0) {
        LoggingService.error('[macOS] Directory copy failed: ${result.stderr}');
        throw UpdateException('Failed to copy directory', sourcePath);
      }

      LoggingService.debug('[macOS] Directory copied successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error copying directory', e);
      rethrow;
    }
  }

  /// Get installation directory for channel (helper method)
  Future<String> getInstallationDirectory(String channel) async {
    final baseDir = await getDefaultInstallPath();
    final channelDir = getChannelFolderName(channel);
    return path.join(baseDir, channelDir);
  }
}
