/// Release channel enumeration
enum ReleaseChannel {
  stable('stable', 'Stable', 'Eden-Release'),
  nightly('nightly', 'Nightly', 'Eden-Nightly');

  const ReleaseChannel(this.value, this.displayName, this.folderName);

  final String value;
  final String displayName;
  final String folderName;

  /// Get channel from string value
  static ReleaseChannel fromString(String value) {
    return values.firstWhere(
      (channel) => channel.value == value,
      orElse: () => stable,
    );
  }
}

/// Update operation status
enum UpdateStatus {
  idle,
  checking,
  downloading,
  extracting,
  installing,
  completed,
  failed;

  bool get isInProgress =>
      [checking, downloading, extracting, installing].contains(this);
  bool get canStartOperation =>
      this == idle || this == completed || this == failed;
}

/// Installation status
enum InstallationStatus {
  notInstalled,
  installed,
  updateAvailable;

  bool get needsInstallation => this == notInstalled;
  bool get hasUpdate => this == updateAvailable;
  bool get canLaunch => this == installed;
}
