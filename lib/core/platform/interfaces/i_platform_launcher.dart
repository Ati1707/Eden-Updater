abstract class IPlatformLauncher {
  Future<void> launchEden();
  Future<void> createDesktopShortcut();
  Future<String?> findEdenExecutable(String installPath, String channel);
}
