import 'dart:io';
import 'package:path/path.dart' as path;
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

  /// Validates an update file using macOS-specific tools and methods
  ///
  /// This method performs format-specific validation:
  /// - DMG files: Uses hdiutil verify to check integrity
  /// - .app bundles: Validates bundle structure and Info.plist
  /// - Archives: Basic file type and accessibility checks
  Future<bool> validateUpdateFile(String filePath) async {
    LoggingService.debug('[macOS] Validating update file: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.error('[macOS] Update file does not exist: $filePath');
        return false;
      }

      final extension = path.extension(filePath).toLowerCase();

      switch (extension) {
        case '.dmg':
          return await _validateDMGFile(filePath);
        case '.app':
          return await _validateAppBundle(filePath);
        case '.zip':
        case '.gz':
          return await _validateArchiveFile(filePath);
        default:
          LoggingService.warning(
            '[macOS] Unknown file type for validation: $extension',
          );
          return await _validateGenericFile(filePath);
      }
    } catch (e) {
      LoggingService.error('[macOS] Error validating update file', e);
      return false;
    }
  }

  /// Validates a DMG file using hdiutil verify
  Future<bool> _validateDMGFile(String dmgPath) async {
    LoggingService.debug('[macOS] Validating DMG file: $dmgPath');

    try {
      // Use hdiutil verify to check DMG integrity
      final result = await Process.run('hdiutil', ['verify', dmgPath]);

      if (result.exitCode == 0) {
        LoggingService.debug('[macOS] DMG file validation successful');
        return true;
      } else {
        LoggingService.error('[macOS] DMG validation failed: ${result.stderr}');
        return false;
      }
    } catch (e) {
      LoggingService.error('[macOS] Error running hdiutil verify', e);
      // Fallback to basic file checks if hdiutil is not available
      return await _validateGenericFile(dmgPath);
    }
  }

  /// Validates an .app bundle structure and Info.plist
  Future<bool> _validateAppBundle(String appPath) async {
    LoggingService.debug('[macOS] Validating .app bundle: $appPath');

    try {
      final appDir = Directory(appPath);
      if (!await appDir.exists()) {
        LoggingService.error('[macOS] .app bundle does not exist: $appPath');
        return false;
      }

      // Check for required .app bundle structure
      final contentsDir = Directory(path.join(appPath, 'Contents'));
      if (!await contentsDir.exists()) {
        LoggingService.error('[macOS] .app bundle missing Contents directory');
        return false;
      }

      final infoPlistPath = path.join(appPath, 'Contents', 'Info.plist');
      final infoPlistFile = File(infoPlistPath);
      if (!await infoPlistFile.exists()) {
        LoggingService.error('[macOS] .app bundle missing Info.plist');
        return false;
      }

      // Validate Info.plist using plutil
      try {
        final result = await Process.run('plutil', ['-lint', infoPlistPath]);
        if (result.exitCode != 0) {
          LoggingService.error('[macOS] Invalid Info.plist: ${result.stderr}');
          return false;
        }
      } catch (e) {
        LoggingService.warning(
          '[macOS] Could not validate Info.plist with plutil',
          e,
        );
        // Continue without plutil validation
      }

      // Check for MacOS directory (executable location)
      final macosDir = Directory(path.join(appPath, 'Contents', 'MacOS'));
      if (!await macosDir.exists()) {
        LoggingService.warning('[macOS] .app bundle missing MacOS directory');
        // This might be acceptable for some bundles
      }

      LoggingService.debug('[macOS] .app bundle validation successful');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error validating .app bundle', e);
      return false;
    }
  }

  /// Validates archive files (ZIP, tar.gz)
  Future<bool> _validateArchiveFile(String archivePath) async {
    LoggingService.debug('[macOS] Validating archive file: $archivePath');

    try {
      final file = File(archivePath);
      final stat = await file.stat();

      // Check if file is readable and has reasonable size
      if (stat.size == 0) {
        LoggingService.error('[macOS] Archive file is empty');
        return false;
      }

      // Use file command to verify file type
      try {
        final result = await Process.run('file', [archivePath]);
        final output = result.stdout.toString().toLowerCase();

        final extension = path.extension(archivePath).toLowerCase();
        if (extension == '.zip' && !output.contains('zip')) {
          LoggingService.error(
            '[macOS] File does not appear to be a valid ZIP archive',
          );
          return false;
        }

        if (extension == '.gz' && !output.contains('gzip')) {
          LoggingService.error(
            '[macOS] File does not appear to be a valid gzip archive',
          );
          return false;
        }
      } catch (e) {
        LoggingService.warning(
          '[macOS] Could not verify file type with file command',
          e,
        );
        // Continue without file type verification
      }

      LoggingService.debug('[macOS] Archive file validation successful');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error validating archive file', e);
      return false;
    }
  }

  /// Generic file validation for unknown file types
  Future<bool> _validateGenericFile(String filePath) async {
    LoggingService.debug(
      '[macOS] Performing generic file validation: $filePath',
    );

    try {
      final file = File(filePath);
      final stat = await file.stat();

      // Basic checks: file exists, is readable, and has content
      if (stat.size == 0) {
        LoggingService.error('[macOS] File is empty');
        return false;
      }

      // Try to read first few bytes to ensure file is accessible
      final bytes = await file.openRead(0, 1024).toList();
      if (bytes.isEmpty) {
        LoggingService.error('[macOS] File is not readable');
        return false;
      }

      LoggingService.debug('[macOS] Generic file validation successful');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error in generic file validation', e);
      return false;
    }
  }

  /// Gets comprehensive update capabilities for macOS platform
  ///
  /// Returns detailed information about what update features are supported,
  /// including channel support, file formats, system tools availability,
  /// and environment information.
  Future<Map<String, dynamic>> getUpdateCapabilities() async {
    LoggingService.debug('[macOS] Getting update capabilities');

    try {
      final capabilities = <String, dynamic>{
        'platform': 'macOS',
        'platformVersion': Platform.operatingSystemVersion,
        'supportedChannels': await _getSupportedChannelsWithValidation(),
        'supportedFileFormats': await _getSupportedFileFormats(),
        'systemTools': await _getAvailableSystemTools(),
        'features': await _getAvailableFeatures(),
        'environment': await _getEnvironmentInformation(),
        'limitations': _getKnownLimitations(),
      };

      LoggingService.debug('[macOS] Update capabilities gathered successfully');
      return capabilities;
    } catch (e) {
      LoggingService.error('[macOS] Error getting update capabilities', e);
      // Return basic capabilities even if detailed detection fails
      return _getBasicCapabilities();
    }
  }

  /// Gets supported channels with validation of their availability
  Future<Map<String, dynamic>> _getSupportedChannelsWithValidation() async {
    final channels = <String, dynamic>{};

    for (final channel in ['stable', 'nightly']) {
      channels[channel] = {
        'supported': isChannelSupported(channel),
        'description': _getChannelDescription(channel),
        'requirements': _getChannelRequirements(channel),
      };
    }

    return channels;
  }

  /// Gets supported file formats with their capabilities
  Future<Map<String, dynamic>> _getSupportedFileFormats() async {
    return {
      'dmg': {
        'supported': true,
        'description': 'macOS Disk Image',
        'validation': 'hdiutil verify',
        'installation': 'mount, extract, unmount',
        'requirements': ['hdiutil'],
      },
      'app': {
        'supported': true,
        'description': 'macOS Application Bundle',
        'validation': 'bundle structure and Info.plist',
        'installation': 'direct copy with permissions',
        'requirements': ['plutil (optional)'],
      },
      'zip': {
        'supported': true,
        'description': 'ZIP Archive',
        'validation': 'file type verification',
        'installation': 'extract with permission setting',
        'requirements': ['unzip or built-in extraction'],
      },
      'tar.gz': {
        'supported': true,
        'description': 'Gzipped Tar Archive',
        'validation': 'file type verification',
        'installation': 'extract with permission setting',
        'requirements': ['tar, gzip or built-in extraction'],
      },
    };
  }

  /// Checks availability of system tools required for updates
  Future<Map<String, dynamic>> _getAvailableSystemTools() async {
    final tools = <String, dynamic>{};

    // Check for hdiutil (DMG handling)
    tools['hdiutil'] = await _checkToolAvailability('hdiutil', ['--version']);

    // Check for plutil (Info.plist validation)
    tools['plutil'] = await _checkToolAvailability('plutil', ['-help']);

    // Check for file command (file type detection)
    tools['file'] = await _checkToolAvailability('file', ['--version']);

    // Check for chmod (permission management)
    tools['chmod'] = await _checkToolAvailability('chmod', ['--version']);

    // Check for pgrep/pkill (process management)
    tools['pgrep'] = await _checkToolAvailability('pgrep', ['-V']);
    tools['pkill'] = await _checkToolAvailability('pkill', ['-V']);

    // Check for open command (launching applications)
    tools['open'] = await _checkToolAvailability('open', ['-h']);

    return tools;
  }

  /// Gets available update features based on system capabilities
  Future<Map<String, dynamic>> _getAvailableFeatures() async {
    final systemTools = await _getAvailableSystemTools();

    return {
      'autoUpdate': true,
      'portableMode': true,
      'shortcuts': {
        'desktop': true,
        'applicationsFolder': true,
        'description':
            'Desktop .command scripts and Applications folder symlinks',
      },
      'processManagement': {
        'detection': systemTools['pgrep']?['available'] ?? false,
        'termination': systemTools['pkill']?['available'] ?? false,
        'description': 'Eden process detection and termination',
      },
      'fileValidation': {
        'dmg': systemTools['hdiutil']?['available'] ?? false,
        'plist': systemTools['plutil']?['available'] ?? false,
        'fileType': systemTools['file']?['available'] ?? false,
        'description': 'Comprehensive file validation using macOS tools',
      },
      'permissionManagement': {
        'executable': systemTools['chmod']?['available'] ?? false,
        'description': 'Automatic executable permission setting',
      },
      'bundleHandling': {
        'appBundles': true,
        'frameworks': true,
        'dylibs': true,
        'description': 'Native macOS bundle and library handling',
      },
    };
  }

  /// Gathers environment information relevant to updates
  Future<Map<String, dynamic>> _getEnvironmentInformation() async {
    final environment = <String, dynamic>{
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'architecture': _getSystemArchitecture(),
      'homeDirectory': Platform.environment['HOME'],
      'userShell': Platform.environment['SHELL'],
      'pathEnvironment': Platform.environment['PATH'],
    };

    // Add system-specific information
    try {
      final unameResult = await Process.run('uname', ['-a']);
      if (unameResult.exitCode == 0) {
        environment['systemInfo'] = unameResult.stdout.toString().trim();
      }
    } catch (e) {
      LoggingService.debug('[macOS] Could not get system info via uname: $e');
    }

    // Check for Rosetta (Apple Silicon compatibility)
    try {
      final rosettaResult = await Process.run('pgrep', ['oahd']);
      environment['rosettaAvailable'] = rosettaResult.exitCode == 0;
    } catch (e) {
      environment['rosettaAvailable'] = false;
    }

    return environment;
  }

  /// Gets known limitations for macOS platform
  Map<String, dynamic> _getKnownLimitations() {
    return {
      'security': [
        'Gatekeeper may block unsigned applications',
        'Quarantine attributes may be applied to downloaded files',
        'System Integrity Protection may restrict certain operations',
      ],
      'permissions': [
        'May require user approval for file system access',
        'Executable permissions must be set manually for extracted files',
      ],
      'compatibility': [
        'Some features may require specific macOS versions',
        'Apple Silicon Macs may need Rosetta for Intel binaries',
      ],
      'tools': [
        'Some validation features depend on system tools availability',
        'hdiutil required for full DMG validation',
        'plutil recommended for Info.plist validation',
      ],
    };
  }

  /// Checks if a system tool is available and functional
  Future<Map<String, dynamic>> _checkToolAvailability(
    String tool,
    List<String> testArgs,
  ) async {
    try {
      final result = await Process.run(tool, testArgs);
      return {
        'available': true,
        'exitCode': result.exitCode,
        'version': result.stdout.toString().trim(),
      };
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  /// Gets description for a release channel
  String _getChannelDescription(String channel) {
    switch (channel.toLowerCase()) {
      case 'stable':
        return 'Stable releases with full testing and validation';
      case 'nightly':
        return 'Nightly builds with latest features (may be unstable)';
      default:
        return 'Unknown channel';
    }
  }

  /// Gets requirements for a release channel
  List<String> _getChannelRequirements(String channel) {
    switch (channel.toLowerCase()) {
      case 'stable':
        return ['macOS 10.14 or later'];
      case 'nightly':
        return ['macOS 10.14 or later', 'Tolerance for potential instability'];
      default:
        return [];
    }
  }

  /// Gets system architecture information
  String _getSystemArchitecture() {
    // Try to determine architecture more precisely
    try {
      return Platform.version.contains('arm64')
          ? 'Apple Silicon (ARM64)'
          : 'Intel (x86_64)';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Returns basic capabilities if detailed detection fails
  Map<String, dynamic> _getBasicCapabilities() {
    return {
      'platform': 'macOS',
      'platformVersion': Platform.operatingSystemVersion,
      'supportedChannels': {
        'stable': {'supported': true},
        'nightly': {'supported': true},
      },
      'supportedFileFormats': {
        'dmg': {'supported': true},
        'app': {'supported': true},
        'zip': {'supported': true},
        'tar.gz': {'supported': true},
      },
      'features': {'autoUpdate': true, 'portableMode': true, 'shortcuts': true},
      'error':
          'Detailed capability detection failed, showing basic information',
    };
  }
}
