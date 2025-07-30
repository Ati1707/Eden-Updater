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

  UpdaterState({
    this.currentVersion,
    this.latestVersion,
    this.status = UpdateStatus.idle,
    this.downloadProgress = 0.0,
    this.releaseChannel = ReleaseChannel.stable,
    bool? createShortcuts,
    this.portableMode = false, // Always false by default
    this.autoLaunchInProgress = false,
  }) : createShortcuts = createShortcuts ?? AppConstants.defaultCreateShortcuts;

  bool get hasUpdate {
    return latestVersion != null &&
        currentVersion != null &&
        latestVersion!.isDifferentFrom(currentVersion);
  }

  bool get isNotInstalled {
    return currentVersion?.isInstalled != true;
  }

  bool get isOperationInProgress => status.isInProgress;
  bool get isChecking => status == UpdateStatus.checking;
  bool get isDownloading => status == UpdateStatus.downloading;
  bool get canStartOperation => status.canStartOperation;

  InstallationStatus get installationStatus {
    if (isNotInstalled) return InstallationStatus.notInstalled;
    if (hasUpdate) return InstallationStatus.updateAvailable;
    return InstallationStatus.installed;
  }

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
