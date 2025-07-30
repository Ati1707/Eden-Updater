import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_file_handler.dart';
import '../../../services/logging_service.dart';

/// Windows-specific file handler implementation
class WindowsFileHandler implements IPlatformFileHandler {
  @override
  bool isEdenExecutable(String filename) {
    final name = filename.toLowerCase();

    // On Windows, prioritize GUI version, avoid command-line version
    // Eden executable should be 'eden.exe'
    return name == 'eden.exe';
  }

  @override
  String getEdenExecutablePath(String installPath, String? channel) {
    // On Windows, the executable is always 'eden.exe' regardless of channel
    return path.join(installPath, 'eden.exe');
  }

  @override
  Future<void> makeExecutable(String filePath) async {
    // On Windows, files are executable by default if they have .exe extension
    // No additional action needed, but we'll log for consistency
    LoggingService.info('Making file executable on Windows: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.warning(
          'File does not exist, cannot make executable: $filePath',
        );
        return;
      }

      // On Windows, executable permission is determined by file extension
      // .exe files are automatically executable
      final extension = path.extension(filePath).toLowerCase();
      if (extension == '.exe') {
        LoggingService.info(
          'File is already executable (Windows .exe): $filePath',
        );
      } else {
        LoggingService.info(
          'File does not have .exe extension, no action needed: $filePath',
        );
      }
    } catch (e) {
      LoggingService.error(
        'Error checking file for executable permissions on Windows',
        e,
      );
      // Don't throw as this is not critical on Windows
    }
  }

  @override
  Future<bool> containsEdenFiles(String folderPath) async {
    LoggingService.info(
      'Checking if Windows folder contains Eden files: $folderPath',
    );

    try {
      final dir = Directory(folderPath);

      if (!await dir.exists()) {
        LoggingService.warning('Directory does not exist: $folderPath');
        return false;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final filename = path.basename(entity.path).toLowerCase();

          // Check for the main executable
          if (isEdenExecutable(filename)) {
            LoggingService.info(
              'Found Eden executable in folder: ${entity.path}',
            );
            return true;
          }

          // Check for other characteristic files of the emulator distribution
          if (filename.contains('eden')) {
            // Look for common Eden-related files
            if (filename.contains('platforms') ||
                filename.contains('imageformats') ||
                filename.contains('bearer') ||
                filename.endsWith('.dll') && filename.contains('qt')) {
              LoggingService.info(
                'Found Eden-related file in folder: ${entity.path}',
              );
              return true;
            }
          }

          // Check for Qt-related DLLs which are common in Eden distributions
          if (filename.startsWith('qt') && filename.endsWith('.dll')) {
            LoggingService.info(
              'Found Qt DLL in folder (likely Eden): ${entity.path}',
            );
            return true;
          }
        }
      }

      LoggingService.info('No Eden files found in folder: $folderPath');
      return false;
    } catch (e) {
      LoggingService.error(
        'Error checking if Windows folder contains Eden files',
        e,
      );
      return false;
    }
  }
}
