import 'dart:io';
import 'package:path/path.dart' as path;

class CleanupUtils {
  static Future<void> cleanupOldDownloads(String installPath) async {
    try {
      final downloadsPath = path.join(installPath, 'downloads');
      final downloadsDir = Directory(downloadsPath);

      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup failures - not critical
    }
  }

  /// Clean up system temporary directories created by Eden Updater
  static Future<void> cleanupSystemTemp() async {
    try {
      final systemTempDir = Directory.systemTemp;

      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          if (name.startsWith('eden_updater_') ||
              name.startsWith('eden_extract_') ||
              name.startsWith('dart_')) {
            try {
              // Only delete if older than 1 hour to avoid interfering with running operations
              final stat = await entity.stat();
              final age = DateTime.now().difference(stat.modified);
              if (age.inHours >= 1) {
                await entity.delete(recursive: true);
              }
            } catch (e) {
              // Ignore individual cleanup failures
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup failures - not critical
    }
  }

  /// Perform general cleanup of old files
  static Future<void> performGeneralCleanup(String installPath) async {
    await cleanupOldDownloads(installPath);
    await cleanupSystemTemp();
  }
}
