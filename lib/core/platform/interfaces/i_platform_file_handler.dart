abstract class IPlatformFileHandler {
  bool isEdenExecutable(String filename);
  String getEdenExecutablePath(String installPath, String? channel);
  Future<void> makeExecutable(String filePath);
  Future<bool> containsEdenFiles(String folderPath);
}
