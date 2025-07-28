import 'dart:io';
import 'package:path/path.dart' as path;

/// Utility functions for file operations
class FileUtils {
  /// Check if a filename represents an Eden executable
  static bool isEdenExecutable(String filename) {
    final name = filename.toLowerCase();
    if (Platform.isWindows) {
      // Prioritize GUI version, avoid command-line version
      return name == 'eden.exe';
    } else {
      return name == 'eden' ||
          name == 'eden-stable' ||
          name == 'eden-nightly' ||
          (name.contains('eden') && !name.contains('.'));
    }
  }

  /// Get the expected Eden executable path for a given install directory
  static String getEdenExecutablePath(String installPath, [String? channel]) {
    if (Platform.isWindows) {
      return path.join(installPath, 'eden.exe');
    } else if (Platform.isLinux && channel != null) {
      // Use channel-specific naming for Linux AppImages
      final fileName = channel == 'nightly' ? 'eden-nightly' : 'eden-stable';
      return path.join(installPath, fileName);
    } else {
      return path.join(installPath, 'eden');
    }
  }

  /// Format file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes == 0) return 'Unknown size';

    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Copy a directory recursively
  static Future<void> copyDirectory(
    String sourcePath,
    String targetPath,
  ) async {
    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);

    await targetDir.create(recursive: true);

    await for (final entity in sourceDir.list()) {
      final name = path.basename(entity.path);
      final targetEntityPath = path.join(targetPath, name);

      if (entity is File) {
        await entity.copy(targetEntityPath);
      } else if (entity is Directory) {
        await copyDirectory(entity.path, targetEntityPath);
      }
    }
  }

  /// Check if a directory contains Eden program files (safer implementation)
  static Future<bool> containsEdenFiles(String folderPath) async {
    final dir = Directory(folderPath);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final filename = path.basename(entity.path).toLowerCase();

        // Check for the main executable
        if (isEdenExecutable(filename)) {
          return true;
        }

        // Check for other characteristic files of the emulator distribution
        if (filename.contains('eden') &&
            (filename.contains('platforms') ||
                filename.endsWith('.appimage'))) {
          return true;
        }
      }
    }

    return false;
  }
}
