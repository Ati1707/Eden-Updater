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

  /// Check if a directory contains Eden-related files
  static Future<bool> containsEdenFiles(String folderPath) async {
    final dir = Directory(folderPath);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final filename = path.basename(entity.path).toLowerCase();

        if (isEdenExecutable(filename)) {
          return true;
        }

        if (filename.contains('eden') ||
            filename.endsWith('.nro') ||
            filename.endsWith('.nsp') ||
            filename.endsWith('.xci')) {
          return true;
        }
      }
    }

    return false;
  }

  /// Get the system architecture for Linux AppImage selection
  static Future<String> getSystemArchitecture() async {
    if (!Platform.isLinux) {
      return 'unknown';
    }

    try {
      final result = await Process.run('uname', ['-m']);
      if (result.exitCode == 0) {
        final arch = result.stdout.toString().trim().toLowerCase();

        // Map common architecture names to AppImage naming conventions
        switch (arch) {
          case 'x86_64':
          case 'amd64':
            return 'amd64';
          case 'aarch64':
          case 'arm64':
            return 'aarch64';
          case 'armv7l':
          case 'armv8l':
          case 'armv9l':
            return 'armv9';
          default:
            // For unknown architectures, default to amd64 (most common)
            return 'amd64';
        }
      }
    } catch (e) {
      // If uname fails, default to amd64
      return 'amd64';
    }

    return 'amd64';
  }
}
