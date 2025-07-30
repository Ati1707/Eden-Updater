import '../../../models/update_info.dart';

/// Context information for platform-specific installation operations
class InstallationContext {
  /// Path to the downloaded update file
  final String filePath;

  /// Path where the application should be installed
  final String installPath;

  /// Information about the update being installed
  final UpdateInfo updateInfo;

  /// Whether to create desktop shortcuts after installation
  final bool createShortcuts;

  /// Whether to use portable mode (keep user data in installation folder)
  final bool portableMode;

  /// Release channel (stable/nightly)
  final String channel;

  /// Progress callback function (0.0 to 1.0)
  final Function(double) onProgress;

  /// Status update callback function
  final Function(String) onStatusUpdate;

  const InstallationContext({
    required this.filePath,
    required this.installPath,
    required this.updateInfo,
    required this.createShortcuts,
    required this.portableMode,
    required this.channel,
    required this.onProgress,
    required this.onStatusUpdate,
  });

  /// Creates a copy of this context with updated values
  InstallationContext copyWith({
    String? filePath,
    String? installPath,
    UpdateInfo? updateInfo,
    bool? createShortcuts,
    bool? portableMode,
    String? channel,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) {
    return InstallationContext(
      filePath: filePath ?? this.filePath,
      installPath: installPath ?? this.installPath,
      updateInfo: updateInfo ?? this.updateInfo,
      createShortcuts: createShortcuts ?? this.createShortcuts,
      portableMode: portableMode ?? this.portableMode,
      channel: channel ?? this.channel,
      onProgress: onProgress ?? this.onProgress,
      onStatusUpdate: onStatusUpdate ?? this.onStatusUpdate,
    );
  }

  @override
  String toString() {
    return 'InstallationContext('
        'filePath: $filePath, '
        'installPath: $installPath, '
        'channel: $channel, '
        'createShortcuts: $createShortcuts, '
        'portableMode: $portableMode'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstallationContext &&
        other.filePath == filePath &&
        other.installPath == installPath &&
        other.updateInfo == updateInfo &&
        other.createShortcuts == createShortcuts &&
        other.portableMode == portableMode &&
        other.channel == channel;
  }

  @override
  int get hashCode => Object.hash(
    filePath,
    installPath,
    updateInfo,
    createShortcuts,
    portableMode,
    channel,
  );
}
