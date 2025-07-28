import 'dart:io';
import 'package:flutter/services.dart';
import '../../core/enums/app_enums.dart';
import '../../core/utils/cleanup_utils.dart';
import '../../services/update_service.dart';
import '../state/updater_state.dart';

/// Controller for managing updater operations and business logic
class UpdaterController {
  final UpdateService _updateService = UpdateService();
  final VoidCallback onStateChanged;

  UpdaterState _state = UpdaterState();
  UpdaterState get state => _state;

  UpdaterController({required this.onStateChanged});

  /// Initialize the controller with optional channel
  Future<void> initialize({String? channel}) async {
    if (channel != null) {
      await _updateService.setReleaseChannel(channel);
    }

    // Clean up old downloads folders and temp files from previous versions
    try {
      final installPath = await _updateService.getInstallPath();
      await CleanupUtils.performGeneralCleanup(installPath);
    } catch (e) {
      // Ignore cleanup failures - not critical for app functionality
    }

    await _loadCurrentVersion();
    await _loadSettings();
  }

  /// Load current version information
  Future<void> _loadCurrentVersion() async {
    final current = await _updateService.getCurrentVersion();
    _updateState(_state.copyWith(currentVersion: current));
  }

  /// Load user settings
  Future<void> _loadSettings() async {
    final channelString = await _updateService.getReleaseChannel();
    final channel = ReleaseChannel.fromString(channelString);
    final createShortcuts = await _updateService.getCreateShortcutsPreference();

    _updateState(
      _state.copyWith(
        releaseChannel: channel,
        createShortcuts: createShortcuts,
        portableMode: false, // Always false on boot (session-only setting)
      ),
    );
  }

  /// Check for updates
  Future<void> checkForUpdates({bool forceRefresh = false}) async {
    _updateState(_state.copyWith(status: UpdateStatus.checking));

    try {
      final latest = await _updateService.getLatestVersion(
        channel: _state.releaseChannel.value,
        forceRefresh: forceRefresh,
      );
      _updateState(
        _state.copyWith(latestVersion: latest, status: UpdateStatus.idle),
      );
    } catch (e) {
      _updateState(_state.copyWith(status: UpdateStatus.failed));
      rethrow; // Let the UI handle the error display
    }
  }

  /// Change release channel
  Future<void> changeReleaseChannel(ReleaseChannel newChannel) async {
    await _updateService.setReleaseChannel(newChannel.value);
    _updateState(
      _state.copyWith(releaseChannel: newChannel, latestVersion: null),
    );

    await _loadCurrentVersion();
    await checkForUpdates(forceRefresh: false);
  }

  /// Download and install update
  Future<void> downloadUpdate() async {
    if (_state.latestVersion == null) return;

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

          _updateState(
            _state.copyWith(status: status, downloadProgress: progress),
          );
        },
        onStatusUpdate: (status) {
          // Status updates can be handled by the UI if needed
        },
      );

      _updateState(
        _state.copyWith(
          status: UpdateStatus.completed,
          currentVersion: _state.latestVersion,
        ),
      );
    } catch (e) {
      _updateState(_state.copyWith(status: UpdateStatus.failed));
      rethrow;
    }
  }

  /// Launch Eden emulator
  Future<void> launchEden() async {
    await _updateService.launchEden();

    // Exit the app after launching Eden
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  /// Update create shortcuts preference
  Future<void> updateCreateShortcuts(bool value) async {
    await _updateService.setCreateShortcutsPreference(value);
    _updateState(_state.copyWith(createShortcuts: value));
  }

  /// Update portable mode preference (session-only, not persisted)
  Future<void> updatePortableMode(bool value) async {
    // Portable mode is session-only and always defaults to false on boot
    _updateState(_state.copyWith(portableMode: value));
  }

  /// Set test version (for debugging)
  Future<void> setTestVersion(String version) async {
    await _updateService.setCurrentVersionForTesting(version);
    await _loadCurrentVersion();
  }

  /// Perform auto-launch sequence
  Future<void> performAutoLaunchSequence() async {
    _updateState(_state.copyWith(autoLaunchInProgress: true));

    // For nightly builds, show warning for 2 seconds before proceeding
    if (_state.releaseChannel == ReleaseChannel.nightly) {
      await Future.delayed(const Duration(seconds: 2));
    }

    // Check for updates
    await checkForUpdates(forceRefresh: false);

    // Download update if available
    if (_state.hasUpdate) {
      await downloadUpdate();
    }

    // Launch Eden after a brief delay
    await Future.delayed(const Duration(milliseconds: 500));
    await launchEden();
  }

  /// Update state and notify listeners
  void _updateState(UpdaterState newState) {
    _state = newState;
    onStateChanged();
  }
}
