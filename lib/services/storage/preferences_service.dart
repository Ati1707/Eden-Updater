import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class PreferencesService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<String?> getCurrentVersion(String channel) async {
    final prefs = await _preferences;
    final channelVersionKey = '${AppConstants.currentVersionKey}_$channel';
    return prefs.getString(channelVersionKey);
  }

  Future<void> setCurrentVersion(String channel, String version) async {
    final prefs = await _preferences;
    final channelVersionKey = '${AppConstants.currentVersionKey}_$channel';
    await prefs.setString(channelVersionKey, version);
  }

  Future<String?> getInstallPath() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.installPathKey);
  }

  Future<void> setInstallPath(String path) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.installPathKey, path);
  }

  Future<String> getReleaseChannel() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.releaseChannelKey) ??
        AppConstants.stableChannel;
  }

  Future<void> setReleaseChannel(String channel) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.releaseChannelKey, channel);
  }

  Future<String?> getEdenExecutablePath(String channel) async {
    final prefs = await _preferences;
    final channelExecKey = '${AppConstants.edenExecutableKey}_$channel';
    return prefs.getString(channelExecKey);
  }

  Future<void> setEdenExecutablePath(String channel, String path) async {
    final prefs = await _preferences;
    final channelExecKey = '${AppConstants.edenExecutableKey}_$channel';
    await prefs.setString(channelExecKey, path);
  }

  Future<bool> getCreateShortcutsPreference() async {
    final prefs = await _preferences;
    return prefs.getBool(AppConstants.createShortcutsKey) ?? true;
  }

  Future<void> setCreateShortcutsPreference(bool createShortcuts) async {
    final prefs = await _preferences;
    await prefs.setBool(AppConstants.createShortcutsKey, createShortcuts);
  }

  Future<DateTime?> getInstallationDate(String channel) async {
    final prefs = await _preferences;
    final channelDateKey = '${AppConstants.installationDateKey}_$channel';
    final dateString = prefs.getString(channelDateKey);
    if (dateString != null) {
      return DateTime.tryParse(dateString);
    }
    return null;
  }

  Future<void> setInstallationDate(String channel, DateTime date) async {
    final prefs = await _preferences;
    final channelDateKey = '${AppConstants.installationDateKey}_$channel';
    await prefs.setString(channelDateKey, date.toIso8601String());
  }

  Future<void> clearVersionInfo(String channel) async {
    final prefs = await _preferences;
    final channelVersionKey = '${AppConstants.currentVersionKey}_$channel';
    final channelExecKey = '${AppConstants.edenExecutableKey}_$channel';
    final channelDateKey = '${AppConstants.installationDateKey}_$channel';

    await prefs.remove(channelVersionKey);
    await prefs.remove(channelExecKey);
    await prefs.remove(channelDateKey);
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

  /// Generic method to remove a value (for Android metadata and other uses)
  Future<void> remove(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }
}
