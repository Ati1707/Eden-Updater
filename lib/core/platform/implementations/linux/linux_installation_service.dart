import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../interfaces/i_platform_installation_service.dart';
import '../../interfaces/i_platform_file_handler.dart';
import '../../../constants/app_constants.dart';
import '../../../services/logging_service.dart';
import '../../../../services/storage/preferences_service.dart';

class LinuxInstallationService implements IPlatformInstallationService {
  final IPlatformFileHandler _fileHandler;
  final PreferencesService _preferencesService;

  LinuxInstallationService(this._fileHandler, this._preferencesService);

  @override
  Future<String> getDefaultInstallPath() async {
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
    final targetFolderName = getChannelFolderName(channel);
    final targetPath = path.join(installPath, targetFolderName);

    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      await cleanEdenFolder(targetPath);
    }

    final installDir = Directory(installPath);
    await for (final entity in installDir.list()) {
      if (entity is Directory) {
        final folderName = path.basename(entity.path);

        if (folderName == 'Eden-Release' || folderName == 'Eden-Nightly') {
          continue;
        }

        if (await _fileHandler.containsEdenFiles(entity.path)) {
          await mergeEdenFolder(entity.path, targetPath);
          await entity.delete(recursive: true);
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
      LoggingService.warning('No Eden executables found in: $installPath');
      return;
    }

    // Prioritize GUI versions over command-line versions
    String? selectedExecutable;

    // First priority: use platform-specific preferred executable
    final preferredExecutable = _fileHandler.getEdenExecutablePath(
      installPath,
      null,
    );
    final preferredName = path.basename(preferredExecutable).toLowerCase();

    for (final exe in foundExecutables) {
      final name = path.basename(exe).toLowerCase();
      if (name == preferredName) {
        selectedExecutable = exe;
        break;
      }
    }

    // Second priority: avoid command-line versions
    if (selectedExecutable == null) {
      for (final exe in foundExecutables) {
        final name = path.basename(exe).toLowerCase();
        if (!name.contains('cmd') && !name.contains('cli')) {
          selectedExecutable = exe;
          break;
        }
      }
    }

    // Fallback: use first found
    selectedExecutable ??= foundExecutables.first;

    await _preferencesService.setEdenExecutablePath(
      channel,
      selectedExecutable,
    );

    // Make the executable file executable (important for Linux)
    await _fileHandler.makeExecutable(selectedExecutable);

    LoggingService.info(
      'Selected Eden executable for Linux: $selectedExecutable',
    );
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
