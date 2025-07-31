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
      await _preferencesService.setInstallationDate(channel, DateTime.now());
      LoggingService.debug(
        '[macOS] Version info and installation date stored successfully',
      );
    } catch (e) {
      LoggingService.error('[macOS] Error storing version info', e);
      rethrow;
    }
  }

  /// Set current version for a channel (implementation of missing interface method)
  Future<void> setCurrentVersion(String channel, String version) async {
    LoggingService.info(
      '[macOS] Setting current version for $channel: $version',
    );

    try {
      await _preferencesService.setCurrentVersion(channel, version);
      await _preferencesService.setInstallationDate(channel, DateTime.now());
      LoggingService.debug('[macOS] Current version set successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error setting current version', e);
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

  /// Get version from Info.plist in .app bundle using plutil
  Future<String?> _getVersionFromInfoPlist(String edenPath) async {
    try {
      final appBundlePath = edenPath.substring(0, edenPath.indexOf('.app') + 4);
      final infoPlistPath = path.join(appBundlePath, 'Contents', 'Info.plist');

      if (!await File(infoPlistPath).exists()) {
        LoggingService.debug('[macOS] Info.plist not found at: $infoPlistPath');
        return null;
      }

      LoggingService.debug('[macOS] Reading Info.plist at: $infoPlistPath');

      // Try CFBundleShortVersionString first (preferred for user-facing version)
      final result = await Process.run('plutil', [
        '-extract',
        'CFBundleShortVersionString',
        'raw',
        infoPlistPath,
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        if (version.isNotEmpty &&
            version != 'null' &&
            _isValidVersion(version)) {
          LoggingService.debug(
            '[macOS] Found CFBundleShortVersionString: $version',
          );
          return version;
        }
      }

      // Try CFBundleVersion as fallback
      final result2 = await Process.run('plutil', [
        '-extract',
        'CFBundleVersion',
        'raw',
        infoPlistPath,
      ]).timeout(const Duration(seconds: 10));

      if (result2.exitCode == 0) {
        final version = result2.stdout.toString().trim();
        if (version.isNotEmpty &&
            version != 'null' &&
            _isValidVersion(version)) {
          LoggingService.debug('[macOS] Found CFBundleVersion: $version');
          return version;
        }
      }

      // Try alternative keys that might contain version information
      final alternativeKeys = [
        'CFBundleGetInfoString',
        'NSHumanReadableCopyright',
      ];

      for (final key in alternativeKeys) {
        try {
          final result = await Process.run('plutil', [
            '-extract',
            key,
            'raw',
            infoPlistPath,
          ]).timeout(const Duration(seconds: 5));

          if (result.exitCode == 0) {
            final content = result.stdout.toString().trim();
            final versionMatch = RegExp(
              r'v?(\d+\.\d+\.\d+)',
            ).firstMatch(content);
            if (versionMatch != null) {
              final version = versionMatch.group(1)!;
              LoggingService.debug('[macOS] Found version in $key: $version');
              return version;
            }
          }
        } catch (e) {
          // Continue to next key
        }
      }

      LoggingService.debug('[macOS] No valid version found in Info.plist');
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
        LoggingService.debug('[macOS] Executable not found at: $edenPath');
        return null;
      }

      // Check if file is executable
      final statResult = await Process.run('stat', ['-f', '%A', edenPath]);
      if (statResult.exitCode != 0) {
        LoggingService.debug('[macOS] Cannot check permissions for: $edenPath');
        return null;
      }

      final permissions = statResult.stdout.toString().trim();
      if (!permissions.contains('755') && !permissions.contains('777')) {
        LoggingService.debug(
          '[macOS] File is not executable: $edenPath (permissions: $permissions)',
        );
        return null;
      }

      LoggingService.debug(
        '[macOS] Querying version from executable: $edenPath',
      );

      // Try different version flags
      final versionFlags = ['--version', '-v', '--help'];

      for (final flag in versionFlags) {
        try {
          final result = await Process.run(edenPath, [
            flag,
          ]).timeout(const Duration(seconds: 10));

          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            final version = _extractVersionFromOutput(output);
            if (version != null) {
              LoggingService.debug(
                '[macOS] Found version with $flag: $version',
              );
              return version;
            }
          }
        } catch (e) {
          // Try next flag
          LoggingService.debug('[macOS] Failed to get version with $flag: $e');
        }
      }

      LoggingService.debug('[macOS] No version found from executable');
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
        'version',
        'release_info.txt',
        'build_info.txt',
      ];

      LoggingService.debug(
        '[macOS] Searching for version files in: $installDir',
      );

      for (final fileName in versionFiles) {
        final versionFile = File(path.join(installDir, fileName));
        if (await versionFile.exists()) {
          try {
            final content = await versionFile.readAsString();
            final lines = content.split('\n');

            // Try each line to find a version
            for (final line in lines) {
              final trimmedLine = line.trim();
              if (trimmedLine.isNotEmpty) {
                // Try to extract version from the line
                final version = _extractVersionFromOutput(trimmedLine);
                if (version != null) {
                  LoggingService.debug(
                    '[macOS] Found version in $fileName: $version',
                  );
                  return version;
                }

                // If the line itself looks like a version, use it
                if (_isValidVersion(trimmedLine)) {
                  LoggingService.debug(
                    '[macOS] Found version in $fileName: $trimmedLine',
                  );
                  return trimmedLine;
                }
              }
            }
          } catch (e) {
            LoggingService.debug('[macOS] Error reading $fileName: $e');
          }
        }
      }

      LoggingService.debug('[macOS] No version files found');
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

  /// Extract version number from text output
  String? _extractVersionFromOutput(String output) {
    // Try different version patterns
    final patterns = [
      RegExp(r'v?(\d+\.\d+\.\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(
        r'version\s*:?\s*v?(\d+\.\d+\.\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(r'eden\s+v?(\d+\.\d+\.\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'build\s+v?(\d+\.\d+\.\d+(?:\.\d+)?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(output);
      if (match != null) {
        final version = match.group(1)!;
        if (_isValidVersion(version)) {
          return version;
        }
      }
    }

    return null;
  }

  /// Validate if a string is a valid version number
  bool _isValidVersion(String version) {
    // Check if it matches semantic versioning pattern
    final semverPattern = RegExp(r'^\d+\.\d+\.\d+(?:\.\d+)?$');
    if (!semverPattern.hasMatch(version)) {
      return false;
    }

    // Additional validation: ensure it's not just zeros
    if (version == '0.0.0' || version == '0.0.0.0') {
      return false;
    }

    return true;
  }

  /// Get installation date for a channel
  Future<DateTime?> getInstallationDate(String channel) async {
    LoggingService.debug(
      '[macOS] Getting installation date for channel: $channel',
    );

    try {
      final date = await _preferencesService.getInstallationDate(channel);
      if (date != null) {
        LoggingService.debug('[macOS] Found installation date: $date');
      } else {
        LoggingService.debug('[macOS] No installation date found');
      }
      return date;
    } catch (e) {
      LoggingService.error('[macOS] Error getting installation date', e);
      return null;
    }
  }

  /// Set installation date for a channel
  Future<void> setInstallationDate(String channel, DateTime date) async {
    LoggingService.info(
      '[macOS] Setting installation date for $channel: $date',
    );

    try {
      await _preferencesService.setInstallationDate(channel, date);
      LoggingService.debug('[macOS] Installation date set successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error setting installation date', e);
      rethrow;
    }
  }

  /// Compare two version strings
  int compareVersions(String version1, String version2) {
    if (!_isValidVersion(version1) || !_isValidVersion(version2)) {
      LoggingService.debug(
        '[macOS] Invalid version format for comparison: $version1 vs $version2',
      );
      return version1.compareTo(version2); // Fallback to string comparison
    }

    final parts1 = version1.split('.').map(int.parse).toList();
    final parts2 = version2.split('.').map(int.parse).toList();

    // Pad shorter version with zeros
    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) {
        return -1;
      } else if (parts1[i] > parts2[i]) {
        return 1;
      }
    }

    return 0; // Versions are equal
  }

  /// Check if version1 is newer than version2
  bool isVersionNewer(String version1, String version2) {
    return compareVersions(version1, version2) > 0;
  }

  /// Check if version1 is older than version2
  bool isVersionOlder(String version1, String version2) {
    return compareVersions(version1, version2) < 0;
  }

  /// Check if two versions are equal
  bool areVersionsEqual(String version1, String version2) {
    return compareVersions(version1, version2) == 0;
  }

  /// Validate version format and content
  bool validateVersion(String version) {
    if (!_isValidVersion(version)) {
      return false;
    }

    try {
      final parts = version.split('.').map(int.parse).toList();

      // Check for reasonable version numbers (not too large)
      for (final part in parts) {
        if (part < 0 || part > 9999) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get version information summary for a channel
  Future<Map<String, dynamic>> getVersionSummary(String channel) async {
    try {
      final currentVersion = await getCurrentVersion(channel);
      final installationDate = await getInstallationDate(channel);
      final installDir = await _getInstallationDirectory(channel);
      final dirExists = await Directory(installDir).exists();

      return {
        'channel': channel,
        'version': currentVersion?.version ?? 'Not installed',
        'isInstalled': currentVersion != null,
        'installationDate': installationDate?.toIso8601String(),
        'installationDirectory': installDir,
        'directoryExists': dirExists,
        'hasValidVersion':
            currentVersion != null && validateVersion(currentVersion.version),
      };
    } catch (e) {
      LoggingService.error('[macOS] Error getting version summary', e);
      return {
        'channel': channel,
        'version': 'Error',
        'isInstalled': false,
        'error': e.toString(),
      };
    }
  }
}
