import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Service for managing application preferences
class PreferencesService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get the current version for a specific channel
  Future<String?> getCurrentVersion(String channel) async {
    final prefs = await _preferences;
    final channelVersionKey = '${AppConstants.currentVersionKey}_$channel';
    return prefs.getString(channelVersionKey);
  }

  /// Set the current version for a specific channel
  Future<void> setCurrentVersion(String channel, String version) async {
    final prefs = await _preferences;
    final channelVersionKey = '${AppConstants.currentVersionKey}_$channel';
    await prefs.setString(channelVersionKey, version);
  }

  /// Get the install path
  Future<String?> getInstallPath() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.installPathKey);
  }

  /// Set the install path
  Future<void> setInstallPath(String path) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.installPathKey, path);
  }

  /// Get the release channel
  Future<String> getReleaseChannel() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.releaseChannelKey) ??
        AppConstants.stableChannel;
  }

  /// Set the release channel
  Future<void> setReleaseChannel(String channel) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.releaseChannelKey, channel);
  }

  /// Get the Eden executable path for a specific channel
  Future<String?> getEdenExecutablePath(String channel) async {
    final prefs = await _preferences;
    final channelExecKey = '${AppConstants.edenExecutableKey}_$channel';
    return prefs.getString(channelExecKey);
  }

  /// Set the Eden executable path for a specific channel
  Future<void> setEdenExecutablePath(String channel, String path) async {
    final prefs = await _preferences;
    final channelExecKey = '${AppConstants.edenExecutableKey}_$channel';
    await prefs.setString(channelExecKey, path);
  }

  /// Get the create shortcuts preference
  Future<bool> getCreateShortcutsPreference() async {
    final prefs = await _preferences;
    return prefs.getBool(AppConstants.createShortcutsKey) ?? true;
  }

  /// Set the create shortcuts preference
  Future<void> setCreateShortcutsPreference(bool createShortcuts) async {
    final prefs = await _preferences;
    await prefs.setBool(AppConstants.createShortcutsKey, createShortcuts);
  }



  /// Clear stored version info for a specific channel
  Future<void> clearVersionInfo(String channel) async {
    final prefs = await _preferences;
    final channelVersionKey = '${AppConstants.currentVersionKey}_$channel';
    final channelExecKey = '${AppConstants.edenExecutableKey}_$channel';

    await prefs.remove(channelVersionKey);
    await prefs.remove(channelExecKey);
  }

  /// Generic method to set a string value (for Android metadata and other uses)
  Future<void> setString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  /// Generic method to get a string value (for Android metadata and other uses)
  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  /// Generic method to remove a key (for clearing test data)
  Future<void> removeKey(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }

  /// Debug method to get all stored preferences (for troubleshooting)
  Future<Map<String, dynamic>> getAllPreferences() async {
    final prefs = await _preferences;
    final keys = prefs.getKeys();
    final result = <String, dynamic>{};

    for (final key in keys) {
      final value = prefs.get(key);
      result[key] = value;
    }

    return result;
  }

  /// Debug method to get all Android version-related data
  Future<Map<String, String?>> getAndroidVersionDebugInfo() async {
    final result = <String, String?>{};

    // Check both channels
    for (final channel in ['stable', 'nightly']) {
      result['current_version_$channel'] = await getCurrentVersion(channel);
      result['android_last_install_$channel'] = await getString(
        'android_last_install_$channel',
      );
      result['android_install_metadata_$channel'] = await getString(
        'android_install_metadata_$channel',
      );
      result['android_install_date_$channel'] = await getString(
        'android_install_date_$channel',
      );
    }

    result['release_channel'] = await getReleaseChannel();
    result['android_preferred_channel'] = await getString(
      'android_preferred_channel',
    );
    result['android_first_run_complete'] = await getString(
      'android_first_run_complete',
    );

    return result;
  }
}
