import 'dart:io';

/// Configuration class that defines platform-specific capabilities and settings
class PlatformConfig {
  /// Human-readable name of the platform
  final String name;

  /// List of file extensions this platform can handle (e.g., ['.exe', '.zip'])
  final List<String> supportedFileExtensions;

  /// List of release channels supported by this platform
  final List<String> supportedChannels;

  /// Whether this platform supports creating desktop shortcuts
  final bool supportsShortcuts;

  /// Whether this platform supports portable mode installation
  final bool supportsPortableMode;

  /// Whether this platform requires executable permissions to be set
  final bool requiresExecutablePermissions;

  /// Default installation directory name for this platform
  final String defaultInstallationDir;

  final List<bool Function(String)> assetSearchPatterns;
  final String defaultArchitecture;
  final Map<String, bool> featureFlags;
  final Map<String, dynamic> platformSpecificConfig;

  const PlatformConfig({
    required this.name,
    required this.supportedFileExtensions,
    required this.supportedChannels,
    required this.supportsShortcuts,
    required this.supportsPortableMode,
    required this.requiresExecutablePermissions,
    required this.defaultInstallationDir,
    required this.assetSearchPatterns,
    required this.defaultArchitecture,
    required this.featureFlags,
    required this.platformSpecificConfig,
  });

  /// Windows platform configuration
  static final windows = PlatformConfig(
    name: 'Windows',
    supportedFileExtensions: const ['.exe', '.zip', '.7z'],
    supportedChannels: const ['stable', 'nightly'],
    supportsShortcuts: true,
    supportsPortableMode: true,
    requiresExecutablePermissions: false,
    defaultInstallationDir: 'Eden',
    assetSearchPatterns: _getWindowsAssetPatterns(),
    defaultArchitecture: 'amd64',
    featureFlags: const {
      'supportsShortcutCreation': true,
      'supportsPortableInstallation': true,
      'requiresAdminRights': false,
      'supportsAutoLaunch': true,
    },
    platformSpecificConfig: const {
      'shortcutExtension': '.lnk',
      'executableExtensions': ['.exe'],
      'archiveExtensions': ['.zip', '.7z'],
      'maxRetries': 10,
      'retryDelaySeconds': 3,
      'requestTimeoutSeconds': 10,
    },
  );

  /// Linux platform configuration
  static final linux = PlatformConfig(
    name: 'Linux',
    supportedFileExtensions: const ['.AppImage', '.tar.gz', '.zip'],
    supportedChannels: const ['stable', 'nightly'],
    supportsShortcuts: true,
    supportsPortableMode:
        false, // Linux doesn't support portable mode - only Windows does
    requiresExecutablePermissions: true,
    defaultInstallationDir: 'Eden',
    assetSearchPatterns: _getLinuxAssetPatterns(),
    defaultArchitecture: 'amd64',
    featureFlags: const {
      'supportsShortcutCreation': true,
      'supportsPortableInstallation':
          false, // Linux doesn't support portable mode
      'requiresExecutablePermissions': true,
      'supportsAutoLaunch': true,
    },
    platformSpecificConfig: const {
      'shortcutExtension': '.desktop',
      'executableExtensions': ['.AppImage'],
      'archiveExtensions': ['.tar.gz', '.zip'],
      'maxRetries': 10,
      'retryDelaySeconds': 3,
      'requestTimeoutSeconds': 10,
    },
  );

  /// Android platform configuration
  static final android = PlatformConfig(
    name: 'Android',
    supportedFileExtensions: const ['.apk'],
    supportedChannels: const [
      'stable',
    ], // Only stable channel supported on Android - nightly doesn't have Android builds
    supportsShortcuts: false,
    supportsPortableMode: false,
    requiresExecutablePermissions: false,
    defaultInstallationDir: '', // Not applicable for Android
    assetSearchPatterns: _getAndroidAssetPatterns(),
    defaultArchitecture: 'arm64',
    featureFlags: const {
      'supportsShortcutCreation': false,
      'supportsPortableInstallation': false,
      'requiresExecutablePermissions': false,
      'supportsAutoLaunch': true,
    },
    platformSpecificConfig: const {
      'packageExtension': '.apk',
      'maxRetries': 10,
      'retryDelaySeconds': 3,
      'requestTimeoutSeconds': 10,
    },
  );

  /// macOS platform configuration (future support)
  static final macos = PlatformConfig(
    name: 'macOS',
    supportedFileExtensions: const ['.dmg', '.app', '.zip'],
    supportedChannels: const ['stable', 'nightly'],
    supportsShortcuts: true,
    supportsPortableMode: true,
    requiresExecutablePermissions: true,
    defaultInstallationDir: 'Eden',
    assetSearchPatterns: _getMacOSAssetPatterns(),
    defaultArchitecture: 'amd64',
    featureFlags: const {
      'supportsShortcutCreation': true,
      'supportsPortableInstallation': true,
      'requiresExecutablePermissions': true,
      'supportsAutoLaunch': true,
    },
    platformSpecificConfig: const {
      'shortcutExtension': '.app',
      'executableExtensions': ['.app'],
      'archiveExtensions': ['.dmg', '.zip'],
      'maxRetries': 10,
      'retryDelaySeconds': 3,
      'requestTimeoutSeconds': 10,
    },
  );

  /// Gets platform-specific configuration value
  T? getConfigValue<T>(String key) {
    return platformSpecificConfig[key] as T?;
  }

  /// Gets platform-specific feature flag
  bool getFeatureFlag(String flag) {
    return featureFlags[flag] ?? false;
  }

  /// Gets network configuration values from platform config
  int get maxRetries => getConfigValue<int>('maxRetries') ?? 10;
  int get retryDelaySeconds => getConfigValue<int>('retryDelaySeconds') ?? 3;
  int get requestTimeoutSeconds =>
      getConfigValue<int>('requestTimeoutSeconds') ?? 10;

  /// Platform-specific asset search patterns for Windows
  static List<bool Function(String)> _getWindowsAssetPatterns() {
    return [
      (String name) =>
          name.contains('windows') &&
          name.contains('x86_64') &&
          name.endsWith('.7z'),
      (String name) =>
          name.contains('windows') &&
          name.contains('amd64') &&
          name.endsWith('.zip'),
      (String name) =>
          name.contains('windows') &&
          (name.contains('x86_64') || name.contains('amd64')) &&
          (name.endsWith('.7z') || name.endsWith('.zip')),
      (String name) =>
          name.contains('windows') &&
          !name.contains('arm64') &&
          !name.contains('aarch64') &&
          (name.endsWith('.7z') || name.endsWith('.zip')),
    ];
  }

  /// Platform-specific asset search patterns for Linux
  static List<bool Function(String)> _getLinuxAssetPatterns() {
    // Detect system architecture
    final systemArch = _getSystemArchitecture();

    return [
      // First priority: Architecture-specific AppImage
      (String name) =>
          name.contains('appimage') &&
          name.contains(systemArch) &&
          !name.contains('zsync'),
      // Second priority: Linux archives with correct architecture
      (String name) =>
          name.contains('linux') &&
          name.contains(systemArch) &&
          name.endsWith('.tar.gz'),
      (String name) =>
          name.contains('linux') &&
          name.contains(systemArch) &&
          name.endsWith('.zip'),
      // Third priority: Generic AppImage (fallback)
      (String name) =>
          name.endsWith('.appimage') &&
          !name.contains('zsync') &&
          !name.contains('aarch64') &&
          !name.contains('armv'),
      // Fourth priority: Any Linux archive (fallback)
      (String name) =>
          name.contains('linux') &&
          name.endsWith('.tar.gz') &&
          !name.contains('aarch64') &&
          !name.contains('armv'),
    ];
  }

  /// Detect system architecture for Linux
  static String _getSystemArchitecture() {
    try {
      // Try to detect architecture from Platform.operatingSystemVersion
      // or use a reasonable default mapping
      final osVersion = Platform.operatingSystemVersion.toLowerCase();

      if (osVersion.contains('x86_64') || osVersion.contains('amd64')) {
        return 'amd64';
      } else if (osVersion.contains('aarch64') || osVersion.contains('arm64')) {
        return 'aarch64';
      } else if (osVersion.contains('armv7') || osVersion.contains('armhf')) {
        return 'armv7';
      } else if (osVersion.contains('armv9')) {
        return 'armv9';
      }

      // Default to amd64 for x86_64 systems
      return 'amd64';
    } catch (e) {
      // Fallback to amd64 if detection fails
      return 'amd64';
    }
  }

  /// Platform-specific asset search patterns for Android
  static List<bool Function(String)> _getAndroidAssetPatterns() {
    return [
      (String name) => name.endsWith('.apk'),
      (String name) => name.contains('android') && name.endsWith('.apk'),
    ];
  }

  /// Platform-specific asset search patterns for macOS
  static List<bool Function(String)> _getMacOSAssetPatterns() {
    return [
      (String name) => name.contains('macos') && name.endsWith('.dmg'),
      (String name) => name.contains('mac') && name.endsWith('.dmg'),
      (String name) => name.contains('darwin') && name.endsWith('.zip'),
      (String name) => name.contains('macos') && name.endsWith('.zip'),
    ];
  }

  @override
  String toString() =>
      'PlatformConfig(name: $name, extensions: $supportedFileExtensions)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlatformConfig &&
        other.name == name &&
        other.supportedFileExtensions.length ==
            supportedFileExtensions.length &&
        other.supportedFileExtensions.every(
          (ext) => supportedFileExtensions.contains(ext),
        );
  }

  @override
  int get hashCode => Object.hash(name, supportedFileExtensions);
}
