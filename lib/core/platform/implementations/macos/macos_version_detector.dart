import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_version_detector.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../../../models/update_info.dart';
import 'macos_file_handler.dart';

/// macOS-specific version detector implementation
class MacOSVersionDetector implements IPlatformVersionDetector {
  final PreferencesService _preferencesService;

  MacOSVersionDetector(this._preferencesService);

  @override
  Future<UpdateInfo?> getCurrentVersion(String channel) async {
    LoggingService.debug(
      '[macOS] Getting current version for channel: $channel',
    );

    try {
      // First try to get version from preferences (cached)
      final cachedVersion = await _preferencesService.getCurrentVersion(
        channel,
      );
      if (cachedVersion != null) {
        LoggingService.debug('[macOS] Found cached version: $cachedVersion');
        return UpdateInfo.fromStoredVersion(cachedVersion);
      }

      // Try to detect version from installed files
      final detectedVersion = await _detectVersionFromInstallation(channel);
      if (detectedVersion != null) {
        LoggingService.info(
          '[macOS] Detected version from installation: $detectedVersion',
        );
        // Cache the detected version
        await _preferencesService.setCurrentVersion(channel, detectedVersion);
        return UpdateInfo.fromStoredVersion(detectedVersion);
      }

      LoggingService.debug('[macOS] No version found for channel: $channel');
      return null;
    } catch (e) {
      LoggingService.error('[macOS] Error getting current version', e);
      return null;
    }
  }

  @override
  Future<void> storeVersionInfo(UpdateInfo updateInfo, String channel) async {
    LoggingService.info(
      '[macOS] Storing version info for $channel: ${updateInfo.version}',
    );

    try {
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);
      LoggingService.debug('[macOS] Version info stored successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error storing version info', e);
      rethrow;
    }
  }

  @override
  Future<void> clearVersionInfo(String channel) async {
    LoggingService.info('[macOS] Clearing version info for channel: $channel');

    try {
      await _preferencesService.clearVersionInfo(channel);
      LoggingService.debug('[macOS] Version info cleared successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error clearing version info', e);
      rethrow;
    }
  }

  /// Detect version from installed files
  Future<String?> _detectVersionFromInstallation(String channel) async {
    LoggingService.debug('[macOS] Detecting version from installation files');

    try {
      final installDir = await _getInstallationDirectory(channel);
      final fileHandler = MacOSFileHandler();

      // Check if installation directory exists
      if (!await Directory(installDir).exists()) {
        LoggingService.debug(
          '[macOS] Installation directory does not exist: $installDir',
        );
        return null;
      }

      final edenPath = fileHandler.getEdenExecutablePath(installDir, channel);

      // Try different methods to detect version
      String? version;

      // Method 1: Try to get version from .app bundle Info.plist
      if (edenPath.contains('.app')) {
        version = await _getVersionFromInfoPlist(edenPath);
        if (version != null) {
          LoggingService.debug(
            '[macOS] Version detected from Info.plist: $version',
          );
          return version;
        }
      }

      // Method 2: Try to run executable with --version flag
      version = await _getVersionFromExecutable(edenPath);
      if (version != null) {
        LoggingService.debug(
          '[macOS] Version detected from executable: $version',
        );
        return version;
      }

      // Method 3: Try to find version file
      version = await _getVersionFromFile(installDir);
      if (version != null) {
        LoggingService.debug(
          '[macOS] Version detected from version file: $version',
        );
        return version;
      }

      LoggingService.debug(
        '[macOS] Could not detect version from installation',
      );
      return null;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error detecting version from installation',
        e,
      );
      return null;
    }
  }

  /// Get version from Info.plist in .app bundle
  Future<String?> _getVersionFromInfoPlist(String edenPath) async {
    try {
      final appBundlePath = edenPath.substring(0, edenPath.indexOf('.app') + 4);
      final infoPlistPath = path.join(appBundlePath, 'Contents', 'Info.plist');

      if (!await File(infoPlistPath).exists()) {
        return null;
      }

      // Use plutil to read version from Info.plist
      final result = await Process.run('plutil', [
        '-extract',
        'CFBundleShortVersionString',
        'raw',
        infoPlistPath,
      ]);

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        if (version.isNotEmpty && version != 'null') {
          return version;
        }
      }

      // Try alternative version key
      final result2 = await Process.run('plutil', [
        '-extract',
        'CFBundleVersion',
        'raw',
        infoPlistPath,
      ]);

      if (result2.exitCode == 0) {
        final version = result2.stdout.toString().trim();
        if (version.isNotEmpty && version != 'null') {
          return version;
        }
      }

      return null;
    } catch (e) {
      LoggingService.debug('[macOS] Error reading Info.plist: $e');
      return null;
    }
  }

  /// Get version by running executable with --version flag
  Future<String?> _getVersionFromExecutable(String edenPath) async {
    try {
      if (!await File(edenPath).exists()) {
        return null;
      }

      // Try running with --version flag
      final result = await Process.run(edenPath, [
        '--version',
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        // Extract version number from output (usually in format "Eden v1.2.3" or "1.2.3")
        final versionMatch = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(output);
        if (versionMatch != null) {
          return versionMatch.group(1);
        }
      }

      return null;
    } catch (e) {
      LoggingService.debug('[macOS] Error getting version from executable: $e');
      return null;
    }
  }

  /// Get version from version file in installation directory
  Future<String?> _getVersionFromFile(String installDir) async {
    try {
      // Common version file names
      final versionFiles = [
        'version.txt',
        'VERSION',
        '.version',
        'eden_version',
      ];

      for (final fileName in versionFiles) {
        final versionFile = File(path.join(installDir, fileName));
        if (await versionFile.exists()) {
          final content = await versionFile.readAsString();
          final version = content.trim();
          if (version.isNotEmpty) {
            return version;
          }
        }
      }

      return null;
    } catch (e) {
      LoggingService.debug('[macOS] Error reading version file: $e');
      return null;
    }
  }

  /// Get installation directory for channel
  Future<String> _getInstallationDirectory(String channel) async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      throw Exception('HOME environment variable not found');
    }

    final baseDir = path.join(homeDir, 'Documents', 'Eden');
    final channelDir = channel == 'nightly' ? 'Eden-Nightly' : 'Eden-Release';
    return path.join(baseDir, channelDir);
  }
}
