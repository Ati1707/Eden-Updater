abstract class IPlatformUpdateService {
  List<String> getSupportedChannels();
  bool isChannelSupported(String channel);
  Future<Map<String, String>?> getInstallationMetadata(String channel);
  Future<void> storeInstallationMetadata(
    String channel,
    Map<String, String> metadata,
  );
  Future<void> clearInstallationMetadata(String channel);
  Map<String, dynamic> getPlatformInfo();
  Future<void> cleanupTempFiles(String? tempDir, String? downloadedFilePath);
}
