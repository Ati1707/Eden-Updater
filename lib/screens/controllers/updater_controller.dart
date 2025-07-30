import 'dart:io';
import 'package:flutter/services.dart';
import '../../core/enums/app_enums.dart';
import '../../core/utils/cleanup_utils.dart';
import '../../services/update_service.dart';
import '../state/updater_state.dart';
import '../../core/services/service_locator.dart'; // Import the service locator
import '../../core/services/logging_service.dart';
import '../../core/platform/platform_factory.dart';
import '../../core/platform/models/platform_config.dart';

/// Controller for managing updater operations and business logic
class UpdaterController {
  // Get the UpdateService from the ServiceLocator for consistency
  final UpdateService _updateService = ServiceLocator().get<UpdateService>();
  final VoidCallback onStateChanged;

  UpdaterState _state = UpdaterState();
  UpdaterState get state => _state;

  UpdaterController({required this.onStateChanged});

  /// Initialize the controller with optional channel
  Future<void> initialize({String? channel}) async {
    LoggingService.info('[UpdaterController] Initializing controller...');

    // Log platform information
    final platformInfo = PlatformFactory.getPlatformInfo();
    LoggingService.info(
      '[UpdaterController] Platform: ${platformInfo['platformName']}',
    );
    LoggingService.info(
      '[UpdaterController] Platform supported: ${platformInfo['isSupported']}',
    );
    LoggingService.debug(
      '[UpdaterController] Platform capabilities: ${platformInfo['supportedChannels']}',
    );
    LoggingService.debug(
      '[UpdaterController] Supports shortcuts: ${platformInfo['supportsShortcuts']}',
    );
    LoggingService.debug(
      '[UpdaterController] Supports portable mode: ${platformInfo['supportsPortableMode']}',
    );

    if (channel != null) {
      LoggingService.info(
        '[UpdaterController] Setting release channel to: $channel',
      );
      await _updateService.setReleaseChannel(channel);
    }

    // Clean up old downloads folders and temp files from previous versions
    try {
      LoggingService.debug(
        '[UpdaterController] Performing cleanup operations...',
      );
      final installPath = await _updateService.getInstallPath();
      LoggingService.debug('[UpdaterController] Install path: $installPath');
      await CleanupUtils.performGeneralCleanup(installPath);
      LoggingService.debug(
        '[UpdaterController] Cleanup completed successfully',
      );
    } catch (e) {
      LoggingService.warning(
        '[UpdaterController] Cleanup failed (non-critical)',
        e,
      );
      // Ignore cleanup failures - not critical for app functionality
    }

    LoggingService.debug(
      '[UpdaterController] Loading current version and settings...',
    );
    await _loadCurrentVersion();
    await _loadSettings();
    LoggingService.info(
      '[UpdaterController] Controller initialization completed',
    );
  }

  Future<void> _loadCurrentVersion() async {
    LoggingService.debug(
      '[UpdaterController] Loading current version information...',
    );
    try {
      final current = await _updateService.getCurrentVersion();
      if (current != null) {
        LoggingService.info(
          '[UpdaterController] Current version loaded: ${current.version}',
        );
      } else {
        LoggingService.info(
          '[UpdaterController] No current version found (not installed)',
        );
      }
      _updateState(_state.copyWith(currentVersion: current));
    } catch (e) {
      LoggingService.error(
        '[UpdaterController] Failed to load current version',
        e,
      );
      rethrow;
    }
  }

  Future<void> _loadSettings() async {
    LoggingService.debug('[UpdaterController] Loading user settings...');
    try {
      final channelString = await _updateService.getReleaseChannel();
      final channel = ReleaseChannel.fromString(channelString);
      final createShortcuts = await _updateService
          .getCreateShortcutsPreference();

      LoggingService.info(
        '[UpdaterController] Release channel: ${channel.value}',
      );
      LoggingService.info(
        '[UpdaterController] Create shortcuts: $createShortcuts',
      );
      LoggingService.debug(
        '[UpdaterController] Portable mode: false (session-only setting)',
      );

      _updateState(
        _state.copyWith(
          releaseChannel: channel,
          createShortcuts: createShortcuts,
          portableMode: false, // Always false on boot (session-only setting)
        ),
      );
      LoggingService.debug(
        '[UpdaterController] User settings loaded successfully',
      );
    } catch (e) {
      LoggingService.error(
        '[UpdaterController] Failed to load user settings',
        e,
      );
      rethrow;
    }
  }

  Future<void> checkForUpdates({bool forceRefresh = false}) async {
    LoggingService.info('[UpdaterController] Checking for updates...');
    LoggingService.info(
      '[UpdaterController] Channel: ${_state.releaseChannel.value}',
    );
    LoggingService.info('[UpdaterController] Force refresh: $forceRefresh');

    _updateState(_state.copyWith(status: UpdateStatus.checking));

    try {
      final latest = await _updateService.getLatestVersion(
        channel: _state.releaseChannel.value,
        forceRefresh: forceRefresh,
      );

      LoggingService.info(
        '[UpdaterController] Latest version found: ${latest.version}',
      );
      if (_state.currentVersion != null) {
        final hasUpdate = latest.version != _state.currentVersion!.version;
        LoggingService.info('[UpdaterController] Update available: $hasUpdate');
        if (hasUpdate) {
          LoggingService.info(
            '[UpdaterController] Current: ${_state.currentVersion!.version} -> Latest: ${latest.version}',
          );
        }
      } else {
        LoggingService.info(
          '[UpdaterController] No current version installed, update available',
        );
      }

      _updateState(
        _state.copyWith(latestVersion: latest, status: UpdateStatus.idle),
      );
      LoggingService.debug(
        '[UpdaterController] Update check completed successfully',
      );
    } catch (e) {
      LoggingService.error('[UpdaterController] Update check failed', e);
      _updateState(_state.copyWith(status: UpdateStatus.failed));
      rethrow; // Let the UI handle the error display
    }
  }

  /// Change release channel
  Future<void> changeReleaseChannel(ReleaseChannel newChannel) async {
    LoggingService.info('[UpdaterController] Changing release channel...');
    LoggingService.info(
      '[UpdaterController] From: ${_state.releaseChannel.value} -> To: ${newChannel.value}',
    );

    try {
      await _updateService.setReleaseChannel(newChannel.value);
      _updateState(
        _state.copyWith(releaseChannel: newChannel, latestVersion: null),
      );

      LoggingService.debug(
        '[UpdaterController] Reloading version info for new channel...',
      );
      await _loadCurrentVersion();
      await checkForUpdates(forceRefresh: false);
      LoggingService.info(
        '[UpdaterController] Release channel changed successfully',
      );
    } catch (e) {
      LoggingService.error(
        '[UpdaterController] Failed to change release channel',
        e,
      );
      rethrow;
    }
  }

  Future<void> downloadUpdate() async {
    if (_state.latestVersion == null) {
      LoggingService.warning(
        '[UpdaterController] Download requested but no latest version available',
      );
      return;
    }

    LoggingService.info(
      '[UpdaterController] Starting download and installation...',
    );
    LoggingService.info(
      '[UpdaterController] Version: ${_state.latestVersion!.version}',
    );
    LoggingService.info(
      '[UpdaterController] Download URL: ${_state.latestVersion!.downloadUrl}',
    );
    LoggingService.info(
      '[UpdaterController] Create shortcuts: ${_state.createShortcuts}',
    );
    LoggingService.info(
      '[UpdaterController] Portable mode: ${_state.portableMode}',
    );
    LoggingService.info(
      '[UpdaterController] File size: ${_state.latestVersion!.fileSize} bytes',
    );

    _updateState(
      _state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0.0),
    );

    try {
      await _updateService.downloadUpdate(
        _state.latestVersion!,
        createShortcuts: _state.createShortcuts,
        portableMode: _state.portableMode,
        onProgress: (progress) {
          final status = progress < 0.5
              ? UpdateStatus.downloading
              : progress < 0.95
              ? UpdateStatus.extracting
              : UpdateStatus.installing;

          // Log progress at key milestones
          if (progress == 0.0) {
            LoggingService.debug('[UpdaterController] Download started');
          } else if (progress >= 0.5 && status == UpdateStatus.extracting) {
            LoggingService.debug(
              '[UpdaterController] Extraction phase started',
            );
          } else if (progress >= 0.95 && status == UpdateStatus.installing) {
            LoggingService.debug(
              '[UpdaterController] Installation phase started',
            );
          }

          _updateState(
            _state.copyWith(status: status, downloadProgress: progress),
          );
        },
        onStatusUpdate: (status) {
          // Only log significant status changes, not progress percentages
          if (!status.contains('%')) {
            LoggingService.debug('[UpdaterController] Status: $status');
          }
        },
      );

      LoggingService.info(
        '[UpdaterController] Download and installation completed successfully',
      );
      _updateState(
        _state.copyWith(
          status: UpdateStatus.completed,
          currentVersion: _state.latestVersion,
        ),
      );
    } catch (e) {
      LoggingService.error(
        '[UpdaterController] Download and installation failed',
        e,
      );
      _updateState(_state.copyWith(status: UpdateStatus.failed));
      rethrow;
    }
  }

  Future<void> launchEden() async {
    LoggingService.info('[UpdaterController] Launching Eden emulator...');
    final platformConfig = PlatformFactory.getCurrentPlatformConfig();
    LoggingService.info('[UpdaterController] Platform: ${platformConfig.name}');

    try {
      await _updateService.launchEden();
      LoggingService.info('[UpdaterController] Eden launched successfully');

      // Exit the app after launching Eden using platform-appropriate method
      _exitUpdaterApp(platformConfig);
    } catch (e) {
      LoggingService.error('[UpdaterController] Failed to launch Eden', e);
      rethrow;
    }
  }

  /// Exit the updater app using platform-appropriate method
  void _exitUpdaterApp(PlatformConfig platformConfig) {
    if (platformConfig.name == 'Android') {
      LoggingService.info(
        '[UpdaterController] Exiting updater app (Android - SystemNavigator.pop)',
      );
      SystemNavigator.pop();
    } else {
      LoggingService.info(
        '[UpdaterController] Exiting updater app (Desktop - exit(0))',
      );
      exit(0);
    }
  }

  /// Update create shortcuts preference
  Future<void> updateCreateShortcuts(bool value) async {
    LoggingService.info(
      '[UpdaterController] Updating create shortcuts preference: $value',
    );
    final platformInfo = PlatformFactory.getPlatformInfo();
    if (!platformInfo['supportsShortcuts'] && value) {
      LoggingService.warning(
        '[UpdaterController] Shortcuts not supported on ${platformInfo['platformName']}, ignoring request',
      );
      return;
    }

    try {
      await _updateService.setCreateShortcutsPreference(value);
      _updateState(_state.copyWith(createShortcuts: value));
      LoggingService.debug(
        '[UpdaterController] Create shortcuts preference updated successfully',
      );
    } catch (e) {
      LoggingService.error(
        '[UpdaterController] Failed to update create shortcuts preference',
        e,
      );
      rethrow;
    }
  }

  /// Update portable mode preference (session-only, not persisted)
  Future<void> updatePortableMode(bool value) async {
    LoggingService.info(
      '[UpdaterController] Updating portable mode preference: $value',
    );
    final platformInfo = PlatformFactory.getPlatformInfo();
    if (!platformInfo['supportsPortableMode'] && value) {
      LoggingService.warning(
        '[UpdaterController] Portable mode not supported on ${platformInfo['platformName']}, ignoring request',
      );
      return;
    }

    LoggingService.debug(
      '[UpdaterController] Portable mode is session-only and not persisted',
    );
    // Portable mode is session-only and always defaults to false on boot
    _updateState(_state.copyWith(portableMode: value));
    LoggingService.debug(
      '[UpdaterController] Portable mode preference updated successfully',
    );
  }

  Future<void> setTestVersion(String version) async {
    LoggingService.info('[UpdaterController] Setting test version: $version');
    try {
      await _updateService.setCurrentVersionForTesting(version);
      await _loadCurrentVersion();
      LoggingService.info('[UpdaterController] Test version set successfully');
    } catch (e) {
      LoggingService.error('[UpdaterController] Failed to set test version', e);
      rethrow;
    }
  }

  /// Perform auto-launch sequence
  Future<void> performAutoLaunchSequence() async {
    LoggingService.info('[UpdaterController] Starting auto-launch sequence...');
    LoggingService.info(
      '[UpdaterController] Channel: ${_state.releaseChannel.value}',
    );
    final platformInfo = PlatformFactory.getPlatformInfo();
    LoggingService.info(
      '[UpdaterController] Platform: ${platformInfo['platformName']}',
    );

    _updateState(_state.copyWith(autoLaunchInProgress: true));

    try {
      // For nightly builds, show warning for 2 seconds before proceeding
      if (_state.releaseChannel == ReleaseChannel.nightly) {
        LoggingService.info(
          '[UpdaterController] Nightly channel detected, showing warning for 2 seconds...',
        );
        await Future.delayed(const Duration(seconds: 2));
      }

      // Check for updates
      LoggingService.debug(
        '[UpdaterController] Auto-launch: Checking for updates...',
      );
      await checkForUpdates(forceRefresh: false);

      // Download update if available
      if (_state.hasUpdate) {
        LoggingService.info(
          '[UpdaterController] Auto-launch: Update available, downloading...',
        );
        await downloadUpdate();
      } else {
        LoggingService.info(
          '[UpdaterController] Auto-launch: No update needed',
        );
      }

      // Launch Eden after a brief delay
      LoggingService.debug(
        '[UpdaterController] Auto-launch: Preparing to launch Eden...',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await launchEden();
    } catch (e) {
      LoggingService.error(
        '[UpdaterController] Auto-launch sequence failed',
        e,
      );
      rethrow;
    }
  }

  /// Update state and notify listeners
  void _updateState(UpdaterState newState) {
    _state = newState;
    onStateChanged();
  }
}
