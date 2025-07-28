/// Application-wide constants
class AppConstants {
  // API URLs
  static const String stableApiUrl =
      'https://api.github.com/repos/eden-emulator/Releases/releases/latest';
  static const String nightlyApiUrl =
      'https://api.github.com/repos/pflyly/eden-nightly/releases/latest';

  // Storage Keys
  static const String currentVersionKey = 'current_version';
  static const String installPathKey = 'install_path';
  static const String releaseChannelKey = 'release_channel';
  static const String edenExecutableKey = 'eden_executable_path';
  static const String createShortcutsKey = 'create_shortcuts';

  // Release Channels
  static const String stableChannel = 'stable';
  static const String nightlyChannel = 'nightly';

  // Platform-specific channel availability
  static const bool androidSupportsNightly =
      false; // Set to true if nightly Android builds become available again

  // Network Configuration
  static const int maxRetries = 10;
  static const Duration retryDelay = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 10);

  // UI Configuration
  static const double defaultBorderRadius = 20.0;
  static const double cardElevation = 8.0;
  static const double buttonElevation = 6.0;

  // Application Behavior
  static const bool defaultCreateShortcuts = true;

  /// Get API URL for the specified channel
  static String getApiUrl(String channel) {
    return channel == nightlyChannel ? nightlyApiUrl : stableApiUrl;
  }

  /// Get channel display name
  static String getChannelDisplayName(String channel) {
    return channel == nightlyChannel ? 'Nightly' : 'Stable';
  }

  /// Get channel folder name
  static String getChannelFolderName(String channel) {
    return channel == nightlyChannel ? 'Eden-Nightly' : 'Eden-Release';
  }
}
