import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../interfaces/i_platform_installation_service.dart';
import '../../interfaces/i_platform_file_handler.dart';
import '../../../constants/app_constants.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';

class AndroidInstallationService implements IPlatformInstallationService {
  final IPlatformFileHandler _fileHandler;
  final PreferencesService _preferencesService;

  AndroidInstallationService(this._fileHandler, this._preferencesService);

  @override
  Future<String> getDefaultInstallPath() async {
    // Android uses app-specific directories
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'Eden');
  }

  @override
  String getChannelFolderName(String channel) {
    return channel == AppConstants.nightlyChannel
        ? 'Eden-Nightly'
        : 'Eden-Release';
  }

  @override
  Future<void> organizeInstallation(String installPath, String channel) async {
    // Android APK installation is handled differently
    // This method is primarily for organizing downloaded APK files
    final targetFolderName = getChannelFolderName(channel);
    final targetPath = path.join(installPath, targetFolderName);

    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      await cleanEdenFolder(targetPath);
    }

    final installDir = Directory(installPath);
    await for (final entity in installDir.list()) {
      if (entity is File) {
        final filename = path.basename(entity.path);
        if (_fileHandler.isEdenExecutable(filename)) {
          // For Android, "executable" means APK file
          final targetFilePath = path.join(targetPath, filename);
          await targetDir.create(recursive: true);
          await entity.copy(targetFilePath);
          await scanAndStoreEdenExecutable(targetPath, channel);
          return;
        }
      }
    }
  }

  @override
  Future<void> scanAndStoreEdenExecutable(
    String installPath,
    String channel,
  ) async {
    List<String> foundExecutables = [];

    await for (final entity in Directory(installPath).list(recursive: true)) {
      if (entity is File) {
        final filename = path.basename(entity.path);
        if (_fileHandler.isEdenExecutable(filename)) {
          foundExecutables.add(entity.path);
        }
      }
    }

    if (foundExecutables.isEmpty) {
      LoggingService.warning('No Eden APK files found in: $installPath');
      return;
    }

    // For Android, just use the first APK found
    final selectedExecutable = foundExecutables.first;

    await _preferencesService.setEdenExecutablePath(
      channel,
      selectedExecutable,
    );

    LoggingService.info('Selected Eden APK for Android: $selectedExecutable');
  }

  @override
  Future<void> cleanEdenFolder(String edenPath) async {
    final edenDir = Directory(edenPath);
    if (!await edenDir.exists()) return;

    LoggingService.info('Cleaning Eden folder: $edenPath');

    await for (final entity in edenDir.list()) {
      final name = path.basename(entity.path).toLowerCase();

      if (name == 'user') {
        LoggingService.info('Preserving user data folder: ${entity.path}');
        continue; // Preserve user data
      }

      try {
        await entity.delete(recursive: true);
        LoggingService.info('Deleted: ${entity.path}');
      } catch (e) {
        LoggingService.warning('Failed to delete: ${entity.path}', e);
        // Continue if we can't delete some files
      }
    }
  }

  @override
  Future<void> mergeEdenFolder(String sourcePath, String targetPath) async {
    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);

    await targetDir.create(recursive: true);
    LoggingService.info('Merging Eden folder from $sourcePath to $targetPath');

    await for (final entity in sourceDir.list()) {
      final name = path.basename(entity.path);
      final targetEntityPath = path.join(targetPath, name);

      try {
        if (entity is File) {
          await entity.copy(targetEntityPath);
          LoggingService.info(
            'Copied file: ${entity.path} -> $targetEntityPath',
          );
        } else if (entity is Directory) {
          await copyDirectory(entity.path, targetEntityPath);
        }
      } catch (e) {
        LoggingService.warning('Failed to copy: ${entity.path}', e);
        // Continue if we can't copy some files
      }
    }
  }

  @override
  Future<void> copyDirectory(String sourcePath, String targetPath) async {
    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);

    await targetDir.create(recursive: true);
    LoggingService.info('Copying directory: $sourcePath -> $targetPath');

    await for (final entity in sourceDir.list()) {
      final name = path.basename(entity.path);
      final targetEntityPath = path.join(targetPath, name);

      try {
        if (entity is File) {
          await entity.copy(targetEntityPath);
        } else if (entity is Directory) {
          await copyDirectory(entity.path, targetEntityPath);
        }
      } catch (e) {
        LoggingService.warning(
          'Failed to copy directory item: ${entity.path}',
          e,
        );
      }
    }
  }
}
