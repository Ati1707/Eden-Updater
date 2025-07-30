import 'dart:io';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/services/logging_service.dart';
import '../core/platform/platform_factory.dart';
import '../core/platform/interfaces/i_platform_installer.dart';
import '../core/platform/interfaces/i_platform_version_detector.dart';
import '../core/platform/interfaces/i_platform_file_handler.dart';
import '../core/platform/interfaces/i_platform_update_service.dart';
import '../models/update_info.dart';
import 'network/github_api_service.dart';
import 'storage/preferences_service.dart';
import 'download/download_service.dart';
import 'installation/installation_service.dart';
import 'launcher/launcher_service.dart';

class UpdateService {
  final GitHubApiService _githubService;
  final PreferencesService _preferencesService;
  final DownloadService _downloadService;
  final LauncherService _launcherService;
  final IPlatformInstaller _platformInstaller;
  final IPlatformVersionDetector _versionDetector;
  final IPlatformFileHandler _platformFileHandler;
  final IPlatformUpdateService _platformUpdateService;

  // Session cache for latest versions to avoid redundant API calls
  final Map<String, UpdateInfo> _sessionCache = {};

  /// Default constructor (creates all dependencies)
  UpdateService()
    : _githubService = GitHubApiService(),
      _preferencesService = PreferencesService(),
      _downloadService = DownloadService(),
      _platformFileHandler = PlatformFactory.createFileHandler(),
      _launcherService = LauncherService(
        PreferencesService(),
        InstallationService(
          PreferencesService(),
          PlatformFactory.createFileHandler(),
        ),
      ),
      _platformInstaller = PlatformFactory.createInstaller(),
      _versionDetector = PlatformFactory.createVersionDetector(),
      _platformUpdateService = PlatformFactory.createUpdateService();

  /// Constructor with dependency injection (for better testing and service locator)
  UpdateService.withServices(
    this._githubService,
    this._preferencesService,
    this._downloadService,
    this._launcherService,
    this._platformInstaller,
    this._versionDetector,
    this._platformUpdateService,
  ) : _platformFileHandler = PlatformFactory.createFileHandler();

  // Channel management
  Future<String> getReleaseChannel() async {
    final channel = await _preferencesService.getReleaseChannel();

    // Check if channel is supported on current platform using platform abstraction
    if (!_platformUpdateService.isChannelSupported(channel)) {
      await setReleaseChannel(AppConstants.stableChannel);
      return AppConstants.stableChannel;
    }

    return channel;
  }

  Future<void> setReleaseChannel(String channel) async {
    // Check if channel is supported on current platform using platform abstraction
    if (!_platformUpdateService.isChannelSupported(channel)) {
      return; // Ignore the request
    }

    await _preferencesService.setReleaseChannel(channel);
  }

  // Shortcuts preference
  Future<bool> getCreateShortcutsPreference() =>
      _preferencesService.getCreateShortcutsPreference();
  Future<void> setCreateShortcutsPreference(bool value) =>
      _preferencesService.setCreateShortcutsPreference(value);

  Future<UpdateInfo?> getCurrentVersion() async {
    final channel = await getReleaseChannel();
    return await _versionDetector.getCurrentVersion(channel);
  }

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
    final platformInfo = _platformUpdateService.getPlatformInfo();
    LoggingService.info('Platform: ${platformInfo['platformName']}');
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

      // Check if the platform installer can handle this file
      if (await _platformInstaller.canHandle(downloadedFilePath)) {
        LoggingService.info(
          'Platform installer can handle file, proceeding with installation',
        );

        // Use platform-specific installer
        await _platformInstaller.install(
          downloadedFilePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: (progress) => onProgress(0.5 + (progress * 0.5)),
          onStatusUpdate: onStatusUpdate,
        );

        // Store version information using platform-specific detector
        final channel = await getReleaseChannel();
        await _versionDetector.storeVersionInfo(updateInfo, channel);
        LoggingService.info(
          'Updated version info for channel $channel to ${updateInfo.version}',
        );

        onProgress(1.0);
        onStatusUpdate('Installation complete!');
      } else {
        LoggingService.error(
          'Platform installer cannot handle file: $downloadedFilePath',
        );
        final platformInfo = _platformUpdateService.getPlatformInfo();
        throw UpdateException(
          'Unsupported file type for this platform',
          'The downloaded file cannot be installed on ${platformInfo['platformName']}',
        );
      }
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

  /// Clean up temporary files and directories using platform abstraction
  Future<void> _cleanupTempFiles(
    Directory? tempDir,
    String? downloadedFilePath,
  ) async {
    await _platformUpdateService.cleanupTempFiles(
      tempDir?.path,
      downloadedFilePath,
    );
  }

  Future<void> launchEden() async {
    await _launcherService.launchEden();
  }

  Future<String> getInstallPath() async {
    final installationService = InstallationService(
      _preferencesService,
      _platformFileHandler,
    );
    return await installationService.getInstallPath();
  }

  Future<void> setInstallPath(String newPath) =>
      _preferencesService.setInstallPath(newPath);

  Future<Map<String, String>?> getInstallationMetadata(String channel) async {
    return await _platformUpdateService.getInstallationMetadata(channel);
  }

  Future<void> storeInstallationMetadata(
    String channel,
    Map<String, String> metadata,
  ) async {
    await _platformUpdateService.storeInstallationMetadata(channel, metadata);
  }

  Future<void> clearInstallationMetadata(String channel) async {
    await _platformUpdateService.clearInstallationMetadata(channel);
  }

  /// Debug method to manually set version for testing
  Future<void> setCurrentVersionForTesting(String version) async {
    final channel = await getReleaseChannel();

    await _preferencesService.setString('test_version_override', version);
    await _preferencesService.setString('test_version_channel', channel);

    await _preferencesService.setCurrentVersion(channel, version);
  }
}
