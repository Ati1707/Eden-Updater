import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:android_intent_plus/android_intent.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/services/logging_service.dart';
import '../core/utils/file_utils.dart';
import '../models/update_info.dart';
import 'network/github_api_service.dart';
import 'storage/preferences_service.dart';
import 'download/download_service.dart';
import 'extraction/extraction_service.dart';
import 'installation/installation_service.dart';
import 'launcher/launcher_service.dart';

/// Main service for managing Eden updates
class UpdateService {
  final GitHubApiService _githubService;
  final PreferencesService _preferencesService;
  final DownloadService _downloadService;
  final ExtractionService _extractionService;
  final InstallationService _installationService;
  final LauncherService _launcherService;

  // Session cache for latest versions to avoid redundant API calls
  final Map<String, UpdateInfo> _sessionCache = {};

  /// Default constructor (creates all dependencies)
  UpdateService()
    : _githubService = GitHubApiService(),
      _preferencesService = PreferencesService(),
      _downloadService = DownloadService(),
      _extractionService = ExtractionService(),
      _installationService = InstallationService(PreferencesService()),
      _launcherService = LauncherService(
        PreferencesService(),
        InstallationService(PreferencesService()),
      );

  /// Constructor with dependency injection (for better testing and service locator)
  UpdateService.withServices(
    this._githubService,
    this._preferencesService,
    this._downloadService,
    this._extractionService,
    this._installationService,
    this._launcherService,
  );

  // Channel management
  Future<String> getReleaseChannel() async {
    final channel = await _preferencesService.getReleaseChannel();

    // On Android, force stable channel if nightly is not supported
    if (Platform.isAndroid &&
        channel == AppConstants.nightlyChannel &&
        !AppConstants.androidSupportsNightly) {
      await setReleaseChannel(AppConstants.stableChannel);
      return AppConstants.stableChannel;
    }

    return channel;
  }

  Future<void> setReleaseChannel(String channel) async {
    // On Android, prevent setting nightly channel if not supported
    if (Platform.isAndroid &&
        channel == AppConstants.nightlyChannel &&
        !AppConstants.androidSupportsNightly) {
      return; // Ignore the request
    }

    await _preferencesService.setReleaseChannel(channel);
  }

  // Shortcuts preference
  Future<bool> getCreateShortcutsPreference() =>
      _preferencesService.getCreateShortcutsPreference();
  Future<void> setCreateShortcutsPreference(bool value) =>
      _preferencesService.setCreateShortcutsPreference(value);

  /// Get the current installed version
  Future<UpdateInfo?> getCurrentVersion() async {
    final channel = await getReleaseChannel();

    // On Android, check for installed APK version differently
    if (Platform.isAndroid) {
      return await _getAndroidCurrentVersion(channel);
    }

    // Desktop version detection logic
    final versionString = await _preferencesService.getCurrentVersion(channel);

    if (versionString != null) {
      final storedExecutablePath = await _preferencesService
          .getEdenExecutablePath(channel);
      if (storedExecutablePath != null &&
          await File(storedExecutablePath).exists()) {
        return UpdateInfo(
          version: versionString,
          downloadUrl: '',
          releaseNotes: '',
          releaseDate: DateTime.now(),
          fileSize: 0,
          releaseUrl: '',
        );
      } else {
        await _preferencesService.clearVersionInfo(channel);
      }
    }

    return UpdateInfo(
      version: 'Not installed',
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
      releaseUrl: '',
    );
  }

  /// Get current version on Android by checking stored installation info
  Future<UpdateInfo?> _getAndroidCurrentVersion(String channel) async {
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
      final metadata = await getAndroidInstallationMetadata(channel);
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
      return UpdateInfo(
        version: 'Not installed',
        downloadUrl: '',
        releaseNotes: '',
        releaseDate: DateTime.now(),
        fileSize: 0,
        releaseUrl: '',
      );
    } catch (e) {
      LoggingService.error('Error checking Android current version', e);
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

  /// Get the latest version from GitHub
  Future<UpdateInfo> getLatestVersion({
    String? channel,
    bool forceRefresh = false,
  }) async {
    final releaseChannel = channel ?? await getReleaseChannel();

    // Check session cache first unless force refresh is requested
    if (!forceRefresh && _sessionCache.containsKey(releaseChannel)) {
      return _sessionCache[releaseChannel]!;
    }

    // Fetch from API and cache the result
    final updateInfo = await _githubService.getLatestRelease(releaseChannel);
    _sessionCache[releaseChannel] = updateInfo;

    return updateInfo;
  }

  /// Download and install an update
  Future<void> downloadUpdate(
    UpdateInfo updateInfo, {
    bool createShortcuts = true,
    bool portableMode = false,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('Starting update download and installation');
    LoggingService.info('Update version: ${updateInfo.version}');
    LoggingService.info('Download URL: ${updateInfo.downloadUrl}');
    LoggingService.info('Platform: ${Platform.operatingSystem}');
    LoggingService.info('Create shortcuts: $createShortcuts');
    LoggingService.info('Portable mode: $portableMode');

    Directory? tempDir;
    String? downloadedFilePath;

    try {
      // Create temporary directory for download
      tempDir = await Directory.systemTemp.createTemp('eden_updater_');
      LoggingService.info('Created temp directory: ${tempDir.path}');
      onStatusUpdate('Preparing download...');

      // Download the file to temp directory
      onStatusUpdate('Starting download...');
      LoggingService.info('Starting file download...');
      downloadedFilePath = await _downloadService.downloadFile(
        updateInfo,
        tempDir.path,
        onProgress: (progress) => onProgress(progress * 0.5),
        onStatusUpdate: onStatusUpdate,
      );
      LoggingService.info('Download completed: $downloadedFilePath');

      // Handle Android APK installation differently
      final isApkFile = await _isApkFile(downloadedFilePath);
      if (Platform.isAndroid && isApkFile) {
        LoggingService.info(
          'Detected Android APK file, using Android installation method',
        );
        await _installAndroidApk(
          downloadedFilePath,
          updateInfo,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
        return;
      } else if (isApkFile && !Platform.isAndroid) {
        LoggingService.warning('APK file detected on non-Android platform');
        throw UpdateException(
          'APK file not supported on this platform',
          'APK files can only be installed on Android devices',
        );
      }

      // Handle Linux AppImage files differently
      final isAppImageFile = await _isAppImageFile(downloadedFilePath);
      if (Platform.isLinux && isAppImageFile) {
        LoggingService.info(
          'Detected Linux AppImage file, using AppImage installation method',
        );
        await _installLinuxAppImage(
          downloadedFilePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
        return;
      } else if (isAppImageFile && !Platform.isLinux) {
        LoggingService.warning('AppImage file detected on non-Linux platform');
        throw UpdateException(
          'AppImage file not supported on this platform',
          'AppImage files can only be used on Linux systems',
        );
      }

      // Handle archive extraction for other platforms
      LoggingService.info('Processing archive for desktop platform');
      final installPath = await _installationService.getInstallPath();
      LoggingService.info('Install path: $installPath');

      // Extract the archive to temp directory first
      onStatusUpdate('Extracting archive...');
      LoggingService.info('Creating extraction temp directory...');
      final extractTempDir = await Directory.systemTemp.createTemp(
        'eden_extract_',
      );
      LoggingService.info('Extraction temp directory: ${extractTempDir.path}');

      LoggingService.info('Starting archive extraction...');
      await _extractionService.extractArchive(
        downloadedFilePath,
        extractTempDir.path,
        onProgress: (progress) {
          onProgress(0.5 + (progress * 0.3));
          onStatusUpdate('Extracting... ${(progress * 100).toInt()}%');
        },
      );
      LoggingService.info('Archive extraction completed');

      // Move extracted files to final location
      onStatusUpdate('Installing files...');
      LoggingService.info('Moving extracted files to install location...');
      await _moveExtractedFiles(extractTempDir.path, installPath);
      LoggingService.info('Files moved successfully');

      // Organize the installation
      onStatusUpdate('Organizing installation...');
      LoggingService.info('Organizing installation structure...');
      await _installationService.organizeInstallation(installPath);
      LoggingService.info('Installation organized');
      onProgress(0.9);

      // Update version info
      final channel = await getReleaseChannel();
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);
      LoggingService.info(
        'Updated version info for channel $channel to ${updateInfo.version}',
      );

      // Create user folder for portable mode in the channel-specific folder
      if (portableMode) {
        onStatusUpdate('Setting up portable mode...');
        LoggingService.info('Setting up portable mode...');
        final channelInstallPath = await _installationService
            .getChannelInstallPath();
        final userPath = path.join(channelInstallPath, 'user');
        await Directory(userPath).create(recursive: true);
        LoggingService.info('Portable mode user directory created: $userPath');
      }

      // Create shortcut if requested
      if (createShortcuts) {
        try {
          await _launcherService.createDesktopShortcut();
        } catch (e) {
          LoggingService.error('Failed to create shortcut', e);
        }
      }

      onProgress(1.0);
      onStatusUpdate('Installation complete!');
    } catch (e) {
      LoggingService.error('Update failed', e);
      if (e is AppException) {
        rethrow;
      }
      throw UpdateException('Update failed', e.toString());
    } finally {
      // Clean up temporary files and directories
      await _cleanupTempFiles(tempDir, downloadedFilePath);
    }
  }

  /// Check if a file is an AppImage by examining its extension and content
  Future<bool> _isAppImageFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Check file extension first
      if (filePath.toLowerCase().endsWith('.appimage')) {
        LoggingService.info('File has .appimage extension');
        return true;
      }

      // Check if filename contains 'appimage' (case insensitive)
      final fileName = path.basename(filePath).toLowerCase();
      if (fileName.contains('appimage')) {
        LoggingService.info('File name contains "appimage"');
        return true;
      }

      return false;
    } catch (e) {
      LoggingService.error('Error checking if file is AppImage', e);
      return filePath.toLowerCase().endsWith('.appimage');
    }
  }

  /// Check if a file is an APK by examining its content
  Future<bool> _isApkFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Check file extension first
      if (filePath.toLowerCase().endsWith('.apk')) {
        LoggingService.info('File has .apk extension');
        return true;
      }

      // Check file signature (APK files are ZIP files starting with PK)
      final bytes = await file.openRead(0, 4).toList();
      if (bytes.isNotEmpty && bytes[0].length >= 2) {
        final signature = bytes[0];
        final isPkSignature = signature[0] == 0x50 && signature[1] == 0x4B;
        LoggingService.info(
          'File signature check - PK signature: $isPkSignature',
        );

        // Additional check: look for AndroidManifest.xml in the ZIP structure
        if (isPkSignature) {
          try {
            final fileBytes = await file.readAsBytes();
            final archive = ZipDecoder().decodeBytes(fileBytes);
            final hasManifest = archive.files.any(
              (f) => f.name == 'AndroidManifest.xml',
            );
            LoggingService.info(
              'AndroidManifest.xml found in archive: $hasManifest',
            );
            return hasManifest;
          } catch (e) {
            LoggingService.warning(
              'Failed to check ZIP contents for AndroidManifest.xml',
              e,
            );
            return isPkSignature; // Fall back to signature check
          }
        }
      }

      return false;
    } catch (e) {
      LoggingService.error('Error checking if file is APK', e);
      return filePath.toLowerCase().endsWith('.apk'); // Fall back to extension
    }
  }

  /// Install Android APK using system package installer with enhanced functionality
  Future<void> _installAndroidApk(
    String apkPath,
    UpdateInfo updateInfo, {
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('Starting Android APK installation');
    LoggingService.info('APK path: $apkPath');
    LoggingService.info('Update version: ${updateInfo.version}');

    try {
      onStatusUpdate('Preparing APK installation...');
      onProgress(0.7);

      final apkFile = File(apkPath);
      LoggingService.info('Checking APK file existence...');
      if (!await apkFile.exists()) {
        LoggingService.error('APK file not found at path: $apkPath');
        throw UpdateException('APK file not found', apkPath);
      }

      final apkSize = await apkFile.length();
      LoggingService.info('APK file size: $apkSize bytes');

      // Store APK in a more accessible location for Android
      final channel = await getReleaseChannel();
      await _storeApkForAndroid(apkFile, updateInfo, channel, onStatusUpdate);

      onStatusUpdate('Opening system installer...');
      onProgress(0.8);
      LoggingService.info('Attempting to launch APK with system installer...');

      // Try multiple installation methods for better compatibility
      bool installationInitiated = false;

      // Method 1: Copy APK to Downloads and use Android Intent
      try {
        // First, copy APK to a more accessible location (Downloads)
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final fileName = 'Eden_${updateInfo.version}.apk';
        final publicApkPath = path.join(downloadsDir.path, fileName);

        // Remove existing file if it exists
        final targetFile = File(publicApkPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
          LoggingService.info('Removed existing APK file');
        }

        await File(apkPath).copy(publicApkPath);
        LoggingService.info('APK copied to public location: $publicApkPath');

        // Use Android Intent to launch the APK installer
        if (Platform.isAndroid) {
          LoggingService.info('Launching APK installer using Android Intent');

          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'file://$publicApkPath',
            type: 'application/vnd.android.package-archive',
            flags: <int>[
              0x10000000, // FLAG_ACTIVITY_NEW_TASK
              0x00000001, // FLAG_GRANT_READ_URI_PERMISSION
            ],
          );

          await intent.launch();
          installationInitiated = true;
          LoggingService.info(
            'APK installer launched successfully via Android Intent',
          );
        }
      } catch (e) {
        LoggingService.warning('Android Intent APK launch failed', e);
      }

      // Method 2: Manual installation guidance (final fallback)
      if (!installationInitiated) {
        LoggingService.info(
          'Automatic installation method failed, providing manual guidance',
        );
        final fileName = 'Eden_${updateInfo.version}.apk';
        onStatusUpdate(
          'APK saved to Downloads as $fileName.\n\n'
          'To install manually:\n'
          '1. Open your file manager\n'
          '2. Go to Downloads folder\n'
          '3. Tap on $fileName\n'
          '4. Allow installation if prompted',
        );
        installationInitiated = true;
      }

      onProgress(0.9);

      // Update version info and store installation metadata
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);
      await _storeAndroidInstallationInfo(updateInfo, channel);

      LoggingService.info(
        'Updated version info for channel $channel to ${updateInfo.version}',
      );

      onProgress(1.0);

      if (installationInitiated) {
        onStatusUpdate('Follow system prompts to complete installation.');
      }

      LoggingService.info('Android APK installation completed successfully');
    } catch (e) {
      LoggingService.error('Android APK installation failed', e);
      if (e is AppException) {
        rethrow;
      }
      throw UpdateException('APK installation failed', e.toString());
    }
  }

  /// Store APK in Android-accessible location with metadata
  Future<void> _storeApkForAndroid(
    File apkFile,
    UpdateInfo updateInfo,
    String channel,
    Function(String) onStatusUpdate,
  ) async {
    try {
      onStatusUpdate('Preparing Android installation...');

      // Store installation metadata for future reference
      final metadata = {
        'version': updateInfo.version,
        'channel': channel,
        'downloadUrl': updateInfo.downloadUrl,
        'installDate': DateTime.now().toIso8601String(),
        'fileSize': (await apkFile.length()).toString(),
      };

      // Save metadata to preferences for auto-update functionality
      await _preferencesService.setString(
        'android_install_metadata_$channel',
        metadata.entries.map((e) => '${e.key}=${e.value}').join('|'),
      );

      LoggingService.info(
        'Stored Android installation metadata for channel: $channel',
      );
    } catch (e) {
      LoggingService.warning('Failed to store Android metadata', e);
      // Non-critical, continue with installation
    }
  }

  /// Store Android installation information for auto-launch functionality
  Future<void> _storeAndroidInstallationInfo(
    UpdateInfo updateInfo,
    String channel,
  ) async {
    try {
      await _preferencesService.setString(
        'android_last_install_$channel',
        updateInfo.version,
      );
      await _preferencesService.setString(
        'android_install_date_$channel',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      LoggingService.warning('Failed to store Android installation info', e);
    }
  }

  /// Install Linux AppImage by copying to install directory and making executable
  Future<void> _installLinuxAppImage(
    String appImagePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('Starting Linux AppImage installation');
    LoggingService.info('AppImage path: $appImagePath');
    LoggingService.info('Update version: ${updateInfo.version}');

    try {
      onStatusUpdate('Preparing AppImage installation...');
      onProgress(0.7);

      final appImageFile = File(appImagePath);
      LoggingService.info('Checking AppImage file existence...');
      if (!await appImageFile.exists()) {
        LoggingService.error('AppImage file not found at path: $appImagePath');
        throw UpdateException('AppImage file not found', appImagePath);
      }

      // Get install path and ensure it exists
      final installPath = await _installationService.getInstallPath();
      final installDir = Directory(installPath);
      if (!await installDir.exists()) {
        LoggingService.info('Creating install directory: $installPath');
        await installDir.create(recursive: true);
      }

      onStatusUpdate('Installing AppImage...');
      onProgress(0.8);

      // Copy AppImage to install directory with channel-specific name
      final channel = await getReleaseChannel();
      final targetFileName = channel == AppConstants.nightlyChannel
          ? 'eden-nightly'
          : 'eden-stable';
      final targetPath = path.join(installPath, targetFileName);
      LoggingService.info(
        'Target AppImage path: $targetPath (channel: $channel)',
      );

      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        LoggingService.info('Removing existing Eden executable');
        await targetFile.delete();
      }

      await appImageFile.copy(targetPath);
      LoggingService.info('AppImage copied successfully');

      // Make the AppImage executable
      onStatusUpdate('Setting executable permissions...');
      LoggingService.info('Making AppImage executable...');
      final chmodResult = await Process.run('chmod', ['+x', targetPath]);
      if (chmodResult.exitCode != 0) {
        LoggingService.warning(
          'Failed to set executable permissions: ${chmodResult.stderr}',
        );
        throw UpdateException(
          'Failed to set executable permissions',
          'chmod command failed: ${chmodResult.stderr}',
        );
      }
      LoggingService.info('AppImage is now executable');

      onProgress(0.85);

      // Update version info and store executable path
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);
      await _preferencesService.setEdenExecutablePath(channel, targetPath);
      LoggingService.info(
        'Updated version info for channel $channel to ${updateInfo.version}',
      );

      if (portableMode) {
        onStatusUpdate('Setting up portable mode...');
        LoggingService.info('Setting up portable mode...');
        final channelInstallPath = await _installationService
            .getChannelInstallPath();
        final userPath = path.join(channelInstallPath, 'user');
        await Directory(userPath).create(recursive: true);
        LoggingService.info('Portable mode user directory created: $userPath');
      }

      onProgress(0.9);

      if (createShortcuts) {
        onStatusUpdate('Creating desktop shortcut...');
        try {
          await _launcherService.createDesktopShortcut();
          LoggingService.info('Desktop shortcut created successfully');
        } catch (e) {
          LoggingService.warning('Failed to create desktop shortcut', e);
        }
      }

      onProgress(1.0);
      onStatusUpdate('AppImage installation complete!');
      LoggingService.info('Linux AppImage installation completed successfully');
    } catch (e) {
      LoggingService.error('Linux AppImage installation failed', e);
      if (e is AppException) {
        rethrow;
      }
      throw UpdateException('AppImage installation failed', e.toString());
    }
  }

  /// Move extracted files from temp directory to install directory
  Future<void> _moveExtractedFiles(
    String extractPath,
    String installPath,
  ) async {
    final extractDir = Directory(extractPath);

    await for (final entity in extractDir.list()) {
      final targetPath = path.join(installPath, path.basename(entity.path));

      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await FileUtils.copyDirectory(entity.path, targetPath);
      }
    }
  }

  /// Clean up temporary files and directories
  Future<void> _cleanupTempFiles(
    Directory? tempDir,
    String? downloadedFilePath,
  ) async {
    try {
      if (downloadedFilePath != null) {
        final file = File(downloadedFilePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      final systemTempDir = Directory.systemTemp;
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          if (name.startsWith('eden_updater_') ||
              name.startsWith('eden_extract_')) {
            try {
              await entity.delete(recursive: true);
            } catch (e) {
              // Ignore
            }
          }
        }
      }
    } catch (e) {
      LoggingService.warning('Failed to cleanup temp files', e);
    }
  }

  /// Launch Eden emulator
  Future<void> launchEden() => _launcherService.launchEden();

  /// Get install path
  Future<String> getInstallPath() => _installationService.getInstallPath();

  /// Set install path
  Future<void> setInstallPath(String newPath) =>
      _preferencesService.setInstallPath(newPath);

  /// Get Android installation metadata for a channel
  Future<Map<String, String>?> getAndroidInstallationMetadata(
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
      LoggingService.error('Failed to get Android installation metadata', e);
      return null;
    }
  }

  /// Debug method to manually set version for testing
  Future<void> setCurrentVersionForTesting(String version) async {
    final channel = await getReleaseChannel();

    await _preferencesService.setString('test_version_override', version);
    await _preferencesService.setString('test_version_channel', channel);

    await _preferencesService.setCurrentVersion(channel, version);
  }
}
