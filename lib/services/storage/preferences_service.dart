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
}
