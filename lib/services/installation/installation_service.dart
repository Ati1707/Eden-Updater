import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/file_utils.dart';
import '../storage/preferences_service.dart';

/// Service for managing Eden installation
class InstallationService {
  final PreferencesService _preferencesService;

  InstallationService(this._preferencesService);

  /// Get the installation path, creating it if necessary
  Future<String> getInstallPath() async {
    String? installPath = await _preferencesService.getInstallPath();

    if (installPath == null) {
      final appDir = await getApplicationDocumentsDirectory();
      installPath = path.join(appDir.path, 'Eden');
      await _preferencesService.setInstallPath(installPath);
    }

    await Directory(installPath).create(recursive: true);
    return installPath;
  }

  /// Get the channel-specific installation path
  Future<String> getChannelInstallPath() async {
    final installPath = await getInstallPath();
    final channel = await _preferencesService.getReleaseChannel();
    final channelFolderName = channel == AppConstants.nightlyChannel
        ? 'Eden-Nightly'
        : 'Eden-Release';
    return path.join(installPath, channelFolderName);
  }

  /// Organize extracted files into proper channel folder
  Future<void> organizeInstallation(String installPath) async {
    final channel = await _preferencesService.getReleaseChannel();
    final targetFolderName = channel == AppConstants.nightlyChannel
        ? 'Eden-Nightly'
        : 'Eden-Release';
    final targetPath = path.join(installPath, targetFolderName);

    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      await _cleanEdenFolder(targetPath);
    }

    final installDir = Directory(installPath);
    await for (final entity in installDir.list()) {
      if (entity is Directory) {
        final folderName = path.basename(entity.path);

        if (folderName == 'Eden-Release' || folderName == 'Eden-Nightly') {
          continue;
        }

        if (await FileUtils.containsEdenFiles(entity.path)) {
          await _mergeEdenFolder(entity.path, targetPath);
          await entity.delete(recursive: true);
          await _scanAndStoreEdenExecutable(targetPath);
          return;
        }
      }
    }
  }

  /// Scan for Eden executable and store its path
  Future<void> _scanAndStoreEdenExecutable(String installPath) async {
    List<String> foundExecutables = [];

    await for (final entity in Directory(installPath).list(recursive: true)) {
      if (entity is File) {
        final filename = path.basename(entity.path);
        if (FileUtils.isEdenExecutable(filename)) {
          foundExecutables.add(entity.path);
        }
      }
    }

    if (foundExecutables.isEmpty) {
      return;
    }

    // Prioritize GUI versions over command-line versions
    String? selectedExecutable;

    // First priority: exact matches
    for (final exe in foundExecutables) {
      final name = path.basename(exe).toLowerCase();
      if (name == 'eden.exe') {
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

    final channel = await _preferencesService.getReleaseChannel();
    await _preferencesService.setEdenExecutablePath(
      channel,
      selectedExecutable,
    );

    if (Platform.isLinux) {
      await Process.run('chmod', ['+x', selectedExecutable]);
    }
  }

  /// Clean existing Eden folder while preserving user data
  Future<void> _cleanEdenFolder(String edenPath) async {
    final edenDir = Directory(edenPath);
    if (!await edenDir.exists()) return;

    await for (final entity in edenDir.list()) {
      final name = path.basename(entity.path).toLowerCase();

      if (name == 'user') {
        continue; // Preserve user data
      }

      try {
        await entity.delete(recursive: true);
      } catch (e) {
        // Continue if we can't delete some files
      }
    }
  }

  /// Merge Eden folder contents
  Future<void> _mergeEdenFolder(String sourcePath, String targetPath) async {
    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);

    await targetDir.create(recursive: true);

    await for (final entity in sourceDir.list()) {
      final name = path.basename(entity.path);
      final targetEntityPath = path.join(targetPath, name);

      try {
        if (entity is File) {
          await entity.copy(targetEntityPath);
        } else if (entity is Directory) {
          await FileUtils.copyDirectory(entity.path, targetEntityPath);
        }
      } catch (e) {
        // Continue if we can't copy some files
      }
    }
  }
}
