/// Abstract interface for platform-specific installation service operations
abstract class IPlatformInstallationService {
  /// Gets the default installation path for the current platform
  Future<String> getDefaultInstallPath();

  /// Gets the channel-specific folder name for the given channel
  String getChannelFolderName(String channel);

  /// Organizes extracted files into proper channel folder
  ///
  /// [installPath] - Base installation path
  /// [channel] - Release channel (stable/nightly)
  Future<void> organizeInstallation(String installPath, String channel);

  /// Scans for Eden executable and stores its path
  ///
  /// [installPath] - Installation path to scan
  /// [channel] - Release channel for storing executable path
  Future<void> scanAndStoreEdenExecutable(String installPath, String channel);

  /// Cleans existing Eden folder while preserving user data
  ///
  /// [edenPath] - Path to Eden installation folder
  Future<void> cleanEdenFolder(String edenPath);

  /// Merges Eden folder contents from source to target
  ///
  /// [sourcePath] - Source folder path
  /// [targetPath] - Target folder path
  Future<void> mergeEdenFolder(String sourcePath, String targetPath);

  /// Copies a directory recursively
  ///
  /// [sourcePath] - Source directory path
  /// [targetPath] - Target directory path
  Future<void> copyDirectory(String sourcePath, String targetPath);
}
