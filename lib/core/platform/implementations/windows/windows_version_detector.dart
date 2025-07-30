import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_version_detector.dart';
import '../../../../models/update_info.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../../../services/installation/installation_service.dart';

import 'windows_file_handler.dart';

/// Windows-specific version detector implementation
class WindowsVersionDetector implements IPlatformVersionDetector {
  final PreferencesService _preferencesService;
  final InstallationService _installationService;

  WindowsVersionDetector(this._preferencesService, this._installationService);

  @override
  Future<UpdateInfo?> getCurrentVersion(String channel) async {
    LoggingService.info(
      'Getting current Windows version for channel: $channel',
    );

    try {
      // Check stored version info in preferences
      final versionString = await _preferencesService.getCurrentVersion(
        channel,
      );

      if (versionString != null) {
        LoggingService.info('Found stored version: $versionString');

        // Verify the executable still exists
        final storedExecutablePath = await _preferencesService
            .getEdenExecutablePath(channel);

        if (storedExecutablePath != null &&
            await File(storedExecutablePath).exists()) {
          LoggingService.info(
            'Executable exists at stored path: $storedExecutablePath',
          );

          return UpdateInfo(
            version: versionString,
            downloadUrl: '',
            releaseNotes: '',
            releaseDate: DateTime.now(),
            fileSize: 0,
            releaseUrl: '',
          );
        } else {
          LoggingService.warning(
            'Stored executable path is invalid, clearing version info',
          );
          await clearVersionInfo(channel);
        }
      }

      // If no stored version or executable not found, check if Eden is actually installed
      final channelInstallPath = await _installationService
          .getChannelInstallPath();
      final fileHandler = WindowsFileHandler();
      final expectedExecutablePath = fileHandler.getEdenExecutablePath(
        channelInstallPath,
        channel,
      );

      if (await File(expectedExecutablePath).exists()) {
        LoggingService.info('Found Eden executable but no version info stored');

        // Eden is installed but we don't have version info
        // Return a generic "installed" status
        return UpdateInfo(
          version: 'Unknown version',
          downloadUrl: '',
          releaseNotes:
              'Eden is installed but version information is not available',
          releaseDate: DateTime.now(),
          fileSize: 0,
          releaseUrl: '',
        );
      }

      LoggingService.info('No Eden installation found for channel: $channel');
      return null;
    } catch (e) {
      LoggingService.error('Error getting current Windows version', e);
      return UpdateInfo(
        version: 'Not installed',
        downloadUrl: '',
        releaseNotes: '',
        releaseDate: DateTime.now(),
        fileSize: 0,
        releaseUrl: '',
      );
    }
  }

  @override
  Future<void> storeVersionInfo(UpdateInfo updateInfo, String channel) async {
    LoggingService.info('Storing Windows version info for channel: $channel');
    LoggingService.info('Version: ${updateInfo.version}');

    try {
      // Store the version string
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);

      // Try to find and store the executable path
      final channelInstallPath = await _installationService
          .getChannelInstallPath();
      final fileHandler = WindowsFileHandler();
      final expectedExecutablePath = fileHandler.getEdenExecutablePath(
        channelInstallPath,
        channel,
      );

      if (await File(expectedExecutablePath).exists()) {
        await _preferencesService.setEdenExecutablePath(
          channel,
          expectedExecutablePath,
        );
        LoggingService.info('Stored executable path: $expectedExecutablePath');
      } else {
        LoggingService.warning(
          'Expected executable not found at: $expectedExecutablePath',
        );

        // Try to find the executable in the installation directory
        final foundExecutable = await _findEdenExecutableInDirectory(
          channelInstallPath,
        );
        if (foundExecutable != null) {
          await _preferencesService.setEdenExecutablePath(
            channel,
            foundExecutable,
          );
          LoggingService.info(
            'Found and stored executable path: $foundExecutable',
          );
        }
      }

      LoggingService.info('Windows version info stored successfully');
    } catch (e) {
      LoggingService.error('Error storing Windows version info', e);
      rethrow;
    }
  }

  @override
  Future<void> clearVersionInfo(String channel) async {
    LoggingService.info('Clearing Windows version info for channel: $channel');

    try {
      await _preferencesService.clearVersionInfo(channel);
      LoggingService.info('Windows version info cleared successfully');
    } catch (e) {
      LoggingService.error('Error clearing Windows version info', e);
      rethrow;
    }
  }

  /// Find Eden executable in the installation directory
  Future<String?> _findEdenExecutableInDirectory(String installPath) async {
    try {
      final installDir = Directory(installPath);

      if (!await installDir.exists()) {
        return null;
      }

      await for (final entity in installDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final fileHandler = WindowsFileHandler();
          if (fileHandler.isEdenExecutable(fileName)) {
            return entity.path;
          }
        }
      }

      return null;
    } catch (e) {
      LoggingService.error('Error searching for Eden executable', e);
      return null;
    }
  }
}
