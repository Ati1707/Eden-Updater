import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_version_detector.dart';
import '../../../../models/update_info.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../../../services/installation/installation_service.dart';

import 'linux_file_handler.dart';

/// Linux-specific version detector implementation
class LinuxVersionDetector implements IPlatformVersionDetector {
  final PreferencesService _preferencesService;
  final InstallationService _installationService;

  LinuxVersionDetector(this._preferencesService, this._installationService);

  @override
  Future<UpdateInfo?> getCurrentVersion(String channel) async {
    LoggingService.info('Getting current Linux version for channel: $channel');

    try {
      // Method 1: Check stored version info in preferences
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

      // Method 2: Check if Eden is actually installed by looking for executable
      final installPath = await _installationService.getInstallPath();
      final fileHandler = LinuxFileHandler();
      final expectedExecutablePath = fileHandler.getEdenExecutablePath(
        installPath,
        channel,
      );

      if (await File(expectedExecutablePath).exists()) {
        LoggingService.info('Found Eden executable but no version info stored');

        // Try to read version from a version file if it exists
        final versionFromFile = await _readVersionFromFile(
          installPath,
          channel,
        );
        if (versionFromFile != null) {
          LoggingService.info('Found version from file: $versionFromFile');

          // Store this version for future reference
          await storeVersionInfo(
            UpdateInfo(
              version: versionFromFile,
              downloadUrl: '',
              releaseNotes: '',
              releaseDate: DateTime.now(),
              fileSize: 0,
              releaseUrl: '',
            ),
            channel,
          );

          return UpdateInfo(
            version: versionFromFile,
            downloadUrl: '',
            releaseNotes: 'Version detected from installation',
            releaseDate: DateTime.now(),
            fileSize: 0,
            releaseUrl: '',
          );
        }

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

      // Method 3: Check for AppImage files in the installation directory
      final appImageVersion = await _detectAppImageVersion(
        installPath,
        channel,
      );
      if (appImageVersion != null) {
        LoggingService.info('Detected AppImage version: $appImageVersion');
        return UpdateInfo(
          version: appImageVersion,
          downloadUrl: '',
          releaseNotes: 'Version detected from AppImage filename',
          releaseDate: DateTime.now(),
          fileSize: 0,
          releaseUrl: '',
        );
      }

      LoggingService.info('No Eden installation found for channel: $channel');
      return UpdateInfo(
        version: 'Not installed',
        downloadUrl: '',
        releaseNotes: '',
        releaseDate: DateTime.now(),
        fileSize: 0,
        releaseUrl: '',
      );
    } catch (e) {
      LoggingService.error('Error getting current Linux version', e);
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
    LoggingService.info('Storing Linux version info for channel: $channel');
    LoggingService.info('Version: ${updateInfo.version}');

    try {
      // Store the version string in preferences
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);

      // Try to find and store the executable path
      final installPath = await _installationService.getInstallPath();
      final fileHandler = LinuxFileHandler();
      final expectedExecutablePath = fileHandler.getEdenExecutablePath(
        installPath,
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
          installPath,
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

      // Write version info to a file for future detection
      await _writeVersionToFile(installPath, channel, updateInfo);

      LoggingService.info('Linux version info stored successfully');
    } catch (e) {
      LoggingService.error('Error storing Linux version info', e);
      rethrow;
    }
  }

  @override
  Future<void> clearVersionInfo(String channel) async {
    LoggingService.info('Clearing Linux version info for channel: $channel');

    try {
      // Clear preferences
      await _preferencesService.clearVersionInfo(channel);

      // Remove version file if it exists
      final installPath = await _installationService.getInstallPath();
      await _removeVersionFile(installPath, channel);

      LoggingService.info('Linux version info cleared successfully');
    } catch (e) {
      LoggingService.error('Error clearing Linux version info', e);
      rethrow;
    }
  }

  /// Read version information from a version file
  Future<String?> _readVersionFromFile(
    String installPath,
    String channel,
  ) async {
    try {
      final versionFilePath = _getVersionFilePath(installPath, channel);
      final versionFile = File(versionFilePath);

      if (await versionFile.exists()) {
        final content = await versionFile.readAsString();
        final lines = content.split('\n');

        for (final line in lines) {
          if (line.startsWith('version=')) {
            final version = line.substring('version='.length).trim();
            if (version.isNotEmpty) {
              LoggingService.info('Read version from file: $version');
              return version;
            }
          }
        }
      }

      return null;
    } catch (e) {
      LoggingService.warning('Error reading version from file', e);
      return null;
    }
  }

  /// Write version information to a file
  Future<void> _writeVersionToFile(
    String installPath,
    String channel,
    UpdateInfo updateInfo,
  ) async {
    try {
      final versionFilePath = _getVersionFilePath(installPath, channel);
      final versionFile = File(versionFilePath);

      // Ensure the directory exists
      final versionDir = Directory(path.dirname(versionFilePath));
      if (!await versionDir.exists()) {
        await versionDir.create(recursive: true);
      }

      final content =
          '''version=${updateInfo.version}
channel=$channel
install_date=${DateTime.now().toIso8601String()}
download_url=${updateInfo.downloadUrl}
file_size=${updateInfo.fileSize}
''';

      await versionFile.writeAsString(content);
      LoggingService.info('Version info written to file: $versionFilePath');
    } catch (e) {
      LoggingService.warning('Error writing version to file', e);
      // Don't throw as this is not critical
    }
  }

  /// Remove version file
  Future<void> _removeVersionFile(String installPath, String channel) async {
    try {
      final versionFilePath = _getVersionFilePath(installPath, channel);
      final versionFile = File(versionFilePath);

      if (await versionFile.exists()) {
        await versionFile.delete();
        LoggingService.info('Version file removed: $versionFilePath');
      }
    } catch (e) {
      LoggingService.warning('Error removing version file', e);
      // Don't throw as this is not critical
    }
  }

  /// Get the path to the version file for a specific channel
  String _getVersionFilePath(String installPath, String channel) {
    return path.join(installPath, '.eden_version_$channel');
  }

  /// Try to detect version from AppImage filename
  Future<String?> _detectAppImageVersion(
    String installPath,
    String channel,
  ) async {
    try {
      final installDir = Directory(installPath);

      if (!await installDir.exists()) {
        return null;
      }

      await for (final entity in installDir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path).toLowerCase();

          // Check if it's an AppImage file
          if (fileName.endsWith('.appimage') || fileName.contains('appimage')) {
            // Enhanced version detection patterns
            final versionPatterns = [
              // Eden_v1.2.3.AppImage, eden-v1.2.3-nightly.AppImage
              RegExp(
                r'eden[_-]?v?([0-9]+\.[0-9]+\.[0-9]+[^\.]*)',
                caseSensitive: false,
              ),
              // Eden-1.2.3.AppImage
              RegExp(r'eden[_-]([0-9]+\.[0-9]+\.[0-9]+)', caseSensitive: false),
              // Eden_20240101.AppImage (date-based versions)
              RegExp(r'eden[_-]([0-9]{8})', caseSensitive: false),
              // Eden_build_123.AppImage (build numbers)
              RegExp(r'eden[_-]build[_-]([0-9]+)', caseSensitive: false),
            ];

            String? detectedVersion;
            for (final pattern in versionPatterns) {
              final match = pattern.firstMatch(fileName);
              if (match != null) {
                detectedVersion = match.group(1);
                break;
              }
            }

            if (detectedVersion != null) {
              // Normalize version format
              final version = detectedVersion.startsWith('v')
                  ? detectedVersion
                  : 'v$detectedVersion';

              LoggingService.info(
                'Detected version from AppImage filename: $version',
              );

              // Store this version for future reference
              await _preferencesService.setCurrentVersion(channel, version);
              await _preferencesService.setEdenExecutablePath(
                channel,
                entity.path,
              );

              return version;
            } else {
              // If no version pattern matches, try to get version from file metadata
              final metadataVersion = await _extractAppImageMetadata(
                entity.path,
              );
              if (metadataVersion != null) {
                LoggingService.info(
                  'Detected version from AppImage metadata: $metadataVersion',
                );

                await _preferencesService.setCurrentVersion(
                  channel,
                  metadataVersion,
                );
                await _preferencesService.setEdenExecutablePath(
                  channel,
                  entity.path,
                );

                return metadataVersion;
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      LoggingService.warning('Error detecting AppImage version', e);
      return null;
    }
  }

  /// Extract version information from AppImage metadata
  Future<String?> _extractAppImageMetadata(String appImagePath) async {
    try {
      // Try to extract version from AppImage using --appimage-extract-and-run
      final result = await Process.run(appImagePath, [
        '--version',
      ], runInShell: true).timeout(const Duration(seconds: 5));

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Look for version patterns in the output
        final versionMatch = RegExp(
          r'v?([0-9]+\.[0-9]+\.[0-9]+)',
        ).firstMatch(output);
        if (versionMatch != null) {
          return 'v${versionMatch.group(1)}';
        }
      }
    } catch (e) {
      LoggingService.info('Could not extract AppImage metadata: $e');
    }

    return null;
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
          final fileHandler = LinuxFileHandler();
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

  /// Get installation metadata for debugging purposes
  Future<Map<String, String>?> getInstallationMetadata(String channel) async {
    try {
      final installPath = await _installationService.getInstallPath();
      final versionFilePath = _getVersionFilePath(installPath, channel);
      final versionFile = File(versionFilePath);

      if (!await versionFile.exists()) {
        return null;
      }

      final content = await versionFile.readAsString();
      final metadata = <String, String>{};

      for (final line in content.split('\n')) {
        if (line.contains('=')) {
          final parts = line.split('=');
          if (parts.length == 2) {
            metadata[parts[0].trim()] = parts[1].trim();
          }
        }
      }

      return metadata;
    } catch (e) {
      LoggingService.error('Error reading installation metadata', e);
      return null;
    }
  }
}
