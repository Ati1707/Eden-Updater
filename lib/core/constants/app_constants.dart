import '../platform/platform_factory.dart';

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

  // UI Configuration
  static const double defaultBorderRadius = 20.0;
  static const double cardElevation = 8.0;
  static const double buttonElevation = 6.0;

  // Platform-aware dynamic values

  /// Gets network configuration from current platform
  static int get maxRetries {
    try {
      return PlatformFactory.getCurrentPlatformConfig().maxRetries;
    } catch (e) {
      return 10; // Fallback value
    }
  }

  /// Gets retry delay from current platform configuration
  static Duration get retryDelay {
    try {
      final seconds =
          PlatformFactory.getCurrentPlatformConfig().retryDelaySeconds;
      return Duration(seconds: seconds);
    } catch (e) {
      return const Duration(seconds: 3); // Fallback value
    }
  }

  /// Gets request timeout from current platform configuration
  static Duration get requestTimeout {
    try {
      final seconds =
          PlatformFactory.getCurrentPlatformConfig().requestTimeoutSeconds;
      return Duration(seconds: seconds);
    } catch (e) {
      return const Duration(seconds: 10); // Fallback value
    }
  }

  /// Gets whether nightly channel is available on current platform
  static bool get nightlyChannelAvailable {
    try {
      return PlatformFactory.getCurrentPlatformConfig().supportedChannels
          .contains(nightlyChannel);
    } catch (e) {
      return false; // Fallback to false for safety
    }
  }

  /// Gets whether shortcuts should be created by default on current platform
  static bool get defaultCreateShortcuts {
    try {
      return PlatformFactory.getCurrentPlatformConfig().supportsShortcuts;
    } catch (e) {
      return false; // Fallback to false for safety
    }
  }

  /// Gets supported channels for current platform
  static List<String> get supportedChannels {
    try {
      return PlatformFactory.getSupportedChannels();
    } catch (e) {
      return [stableChannel]; // Fallback to stable only
    }
  }

  /// Gets supported file extensions for current platform
  static List<String> get supportedFileExtensions {
    try {
      return PlatformFactory.getSupportedFileExtensions();
    } catch (e) {
      return []; // Fallback to empty list
    }
  }

  /// Checks if a specific channel is supported on current platform
  static bool isChannelSupported(String channel) {
    try {
      return PlatformFactory.isChannelSupported(channel);
    } catch (e) {
      return channel == stableChannel; // Fallback to stable only
    }
  }

  /// Checks if a specific feature is supported on current platform
  static bool isFeatureSupported(String feature) {
    try {
      final config = PlatformFactory.getCurrentPlatformConfig();
      return config.getFeatureFlag(feature);
    } catch (e) {
      return false; // Fallback to false for safety
    }
  }

  /// Gets platform-specific configuration value
  static T? getPlatformConfigValue<T>(String key) {
    try {
      final config = PlatformFactory.getCurrentPlatformConfig();
      return config.getConfigValue<T>(key);
    } catch (e) {
      return null; // Fallback to null
    }
  }
}
