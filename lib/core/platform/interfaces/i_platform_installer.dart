import '../../../models/update_info.dart';

/// Abstract interface for platform-specific installation operations
abstract class IPlatformInstaller {
  /// Checks if this installer can handle the given file type
  Future<bool> canHandle(String filePath);

  /// Installs the update from the given file path
  ///
  /// [filePath] - Path to the downloaded update file
  /// [updateInfo] - Information about the update being installed
  /// [createShortcuts] - Whether to create desktop shortcuts
  /// [portableMode] - Whether to use portable mode installation
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  /// [onStatusUpdate] - Callback for status message updates
  Future<void> install(
    String filePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  });

  /// Performs any post-installation setup required for the platform
  ///
  /// [installPath] - Path where the application was installed
  /// [updateInfo] - Information about the installed update
  Future<void> postInstallSetup(String installPath, UpdateInfo updateInfo);
}
