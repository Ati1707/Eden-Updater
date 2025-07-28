import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../models/update_info.dart';

/// Immutable state class for the updater screen
class UpdaterState {
  // Version information
  final UpdateInfo? currentVersion;
  final UpdateInfo? latestVersion;

  // Operation states
  final UpdateStatus status;
  final double downloadProgress;

  // Settings
  final ReleaseChannel releaseChannel;
  final bool createShortcuts;
  final bool portableMode;

  // Auto-launch state
  final bool autoLaunchInProgress;

  const UpdaterState({
    this.currentVersion,
    this.latestVersion,
    this.status = UpdateStatus.idle,
    this.downloadProgress = 0.0,
    this.releaseChannel = ReleaseChannel.stable,
    this.createShortcuts = AppConstants.defaultCreateShortcuts,
    this.portableMode = false, // Always false by default
    this.autoLaunchInProgress = false,
  });

  /// Computed properties for better readability

  /// Check if an update is available
  bool get hasUpdate {
    return latestVersion != null &&
        currentVersion != null &&
        latestVersion!.isDifferentFrom(currentVersion);
  }

  /// Check if Eden is not installed
  bool get isNotInstalled {
    return currentVersion?.isInstalled != true;
  }

  /// Check if any operation is in progress
  bool get isOperationInProgress => status.isInProgress;

  /// Check if currently checking for updates
  bool get isChecking => status == UpdateStatus.checking;

  /// Check if currently downloading
  bool get isDownloading => status == UpdateStatus.downloading;

  /// Check if can start a new operation
  bool get canStartOperation => status.canStartOperation;

  /// Get installation status
  InstallationStatus get installationStatus {
    if (isNotInstalled) return InstallationStatus.notInstalled;
    if (hasUpdate) return InstallationStatus.updateAvailable;
    return InstallationStatus.installed;
  }

  /// Create a copy of the state with updated values
  UpdaterState copyWith({
    UpdateInfo? currentVersion,
    UpdateInfo? latestVersion,
    UpdateStatus? status,
    double? downloadProgress,
    ReleaseChannel? releaseChannel,
    bool? createShortcuts,
    bool? portableMode,
    bool? autoLaunchInProgress,
  }) {
    return UpdaterState(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      releaseChannel: releaseChannel ?? this.releaseChannel,
      createShortcuts: createShortcuts ?? this.createShortcuts,
      portableMode: portableMode ?? this.portableMode,
      autoLaunchInProgress: autoLaunchInProgress ?? this.autoLaunchInProgress,
    );
  }

  @override
  String toString() {
    return 'UpdaterState('
        'status: $status, '
        'channel: ${releaseChannel.displayName}, '
        'hasUpdate: $hasUpdate, '
        'isNotInstalled: $isNotInstalled'
        ')';
  }
}
