import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_installer.dart';
import '../../../../models/update_info.dart';
import '../../../errors/app_exceptions.dart';
import '../../../services/logging_service.dart';
import '../../../utils/file_utils.dart';
import '../../../../services/extraction/extraction_service.dart';
import '../../../../services/installation/installation_service.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../interfaces/i_platform_launcher.dart';
import '../linux/linux_launcher.dart';
import '../../../constants/app_constants.dart';
import 'linux_file_handler.dart';

/// Linux-specific installer implementation
class LinuxInstaller implements IPlatformInstaller {
  final ExtractionService _extractionService;
  final InstallationService _installationService;
  final PreferencesService _preferencesService;
  final IPlatformLauncher _platformLauncher;

  LinuxInstaller(
    this._extractionService,
    this._installationService,
    this._preferencesService,
  ) : _platformLauncher = LinuxLauncher(
        _preferencesService,
        _installationService,
      );

  @override
  Future<bool> canHandle(String filePath) async {
    try {
      LoggingService.debug(
        '[Linux] Checking if installer can handle file: $filePath',
      );

      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('[Linux] File does not exist: $filePath');
        return false;
      }

      // Linux installer handles AppImage files and archive files
      // but not APK files
      final extension = path.extension(filePath).toLowerCase();
      final fileName = path.basename(filePath).toLowerCase();

      LoggingService.debug(
        '[Linux] File extension: $extension, filename: $fileName',
      );

      // Check for AppImage files
      if (extension == '.appimage' || fileName.contains('appimage')) {
        LoggingService.debug('[Linux] Accepting AppImage file: $fileName');
        return true;
      }

      // Supported archive formats for Linux
      final supportedExtensions = ['.zip', '.tar', '.gz', '.bz2', '.xz'];

      // Check if it's a supported archive format
      if (supportedExtensions.any((ext) => extension.endsWith(ext))) {
        LoggingService.debug('[Linux] Accepting archive format: $extension');
        return true;
      }

      // Check for compound extensions like .tar.gz, .tar.bz2, .tar.xz
      if (fileName.endsWith('.tar.gz') ||
          fileName.endsWith('.tar.bz2') ||
          fileName.endsWith('.tar.xz')) {
        LoggingService.debug(
          '[Linux] Accepting compound archive format: $fileName',
        );
        return true;
      }

      // Reject APK files
      if (extension == '.apk') {
        LoggingService.debug('[Linux] Rejecting APK file: $extension');
        return false;
      }

      LoggingService.debug('[Linux] Cannot handle file: $filePath');
      return false;
    } catch (e) {
      LoggingService.error(
        '[Linux] Error checking if installer can handle file: $filePath',
        e,
      );
      return false;
    }
  }

  @override
  Future<void> install(
    String filePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('[Linux] Starting installation operation');
    LoggingService.info('[Linux] File path: $filePath');
    LoggingService.info('[Linux] Update version: ${updateInfo.version}');
    LoggingService.info('[Linux] Create shortcuts: $createShortcuts');
    LoggingService.info('[Linux] Portable mode: $portableMode');
    LoggingService.debug(
      '[Linux] Platform: Linux ${Platform.operatingSystemVersion}',
    );

    try {
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.error('[Linux] Installation file not found: $filePath');
        throw UpdateException('Installation file not found', filePath);
      }

      // Check if it's an AppImage file
      LoggingService.debug('[Linux] Determining installation method...');
      if (await _isAppImageFile(filePath)) {
        LoggingService.info('[Linux] Installing as AppImage');
        await _installAppImage(
          filePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      } else {
        LoggingService.info('[Linux] Installing as archive');
        // Handle archive installation
        await _installArchive(
          filePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      }

      LoggingService.info(
        '[Linux] Installation operation completed successfully',
      );
    } catch (e) {
      LoggingService.error('[Linux] Installation operation failed', e);
      if (e is AppException) {
        rethrow;
      }
      throw UpdateException('Linux installation failed', e.toString());
    }
  }

  @override
  Future<void> postInstallSetup(
    String installPath,
    UpdateInfo updateInfo,
  ) async {
    LoggingService.info('[Linux] Performing post-install setup');
    LoggingService.debug('[Linux] Install path: $installPath');
    LoggingService.debug('[Linux] Update version: ${updateInfo.version}');

    try {
      // Find and verify the Eden executable exists
      final channel = await _preferencesService.getReleaseChannel();
      LoggingService.debug('[Linux] Channel: $channel');

      final fileHandler = LinuxFileHandler();
      final expectedExecutablePath = fileHandler.getEdenExecutablePath(
        installPath,
        channel,
      );

      LoggingService.debug(
        '[Linux] Expected executable path: $expectedExecutablePath',
      );

      if (await File(expectedExecutablePath).exists()) {
        // Store the executable path for future launches
        await _preferencesService.setEdenExecutablePath(
          channel,
          expectedExecutablePath,
        );
        LoggingService.info(
          '[Linux] Stored Eden executable path: $expectedExecutablePath',
        );

        // Ensure the executable has proper permissions
        LoggingService.debug('[Linux] Setting executable permissions...');
        await _makeExecutable(expectedExecutablePath);
      } else {
        LoggingService.warning(
          '[Linux] Eden executable not found at expected path: $expectedExecutablePath',
        );

        // Try to find the executable in the installation directory
        LoggingService.debug(
          '[Linux] Searching for Eden executable in installation directory...',
        );
        final foundExecutable = await _findEdenExecutableInDirectory(
          installPath,
        );
        if (foundExecutable != null) {
          await _preferencesService.setEdenExecutablePath(
            channel,
            foundExecutable,
          );
          LoggingService.info(
            '[Linux] Found and stored Eden executable path: $foundExecutable',
          );

          // Ensure the executable has proper permissions
          LoggingService.debug(
            '[Linux] Setting executable permissions for found executable...',
          );
          await _makeExecutable(foundExecutable);
        } else {
          LoggingService.error(
            '[Linux] Could not find Eden executable in installation directory',
          );
        }
      }
    } catch (e) {
      LoggingService.error('[Linux] Error during post-install setup', e);
      // Don't throw here as the main installation was successful
    }
  }

  /// Install AppImage by copying to install directory and making executable
  Future<void> _installAppImage(
    String appImagePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('Installing Linux AppImage');
    LoggingService.info('AppImage path: $appImagePath');

    onStatusUpdate('Preparing AppImage installation...');
    onProgress(0.1);

    final appImageFile = File(appImagePath);
    if (!await appImageFile.exists()) {
      throw UpdateException('AppImage file not found', appImagePath);
    }

    // Get install path and ensure it exists
    final installPath = await _installationService.getInstallPath();
    final installDir = Directory(installPath);
    if (!await installDir.exists()) {
      LoggingService.info('Creating install directory: $installPath');
      await installDir.create(recursive: true);
    }

    onStatusUpdate('Installing AppImage...');
    onProgress(0.3);

    // Copy AppImage to install directory with channel-specific name
    final channel = await _preferencesService.getReleaseChannel();
    final targetFileName = channel == AppConstants.nightlyChannel
        ? 'eden-nightly'
        : 'eden-stable';
    final targetPath = path.join(installPath, targetFileName);
    LoggingService.info(
      'Target AppImage path: $targetPath (channel: $channel)',
    );

    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      LoggingService.info('Removing existing Eden executable');
      await targetFile.delete();
    }

    await appImageFile.copy(targetPath);
    LoggingService.info('AppImage copied successfully');
    onProgress(0.6);

    // Make the AppImage executable
    onStatusUpdate('Setting executable permissions...');
    LoggingService.info('Making AppImage executable...');
    await _makeExecutable(targetPath);
    LoggingService.info('AppImage is now executable');
    onProgress(0.7);

    // Update version info and store executable path
    await _preferencesService.setCurrentVersion(channel, updateInfo.version);
    await _preferencesService.setEdenExecutablePath(channel, targetPath);
    LoggingService.info(
      'Updated version info for channel $channel to ${updateInfo.version}',
    );

    // Create user folder for portable mode in the channel-specific folder
    if (portableMode) {
      onStatusUpdate('Setting up portable mode...');
      LoggingService.info('Setting up portable mode...');
      final channelInstallPath = await _installationService
          .getChannelInstallPath();
      final userPath = path.join(channelInstallPath, 'user');
      await Directory(userPath).create(recursive: true);
      LoggingService.info('Portable mode user directory created: $userPath');
    }
    onProgress(0.9);

    // Create shortcut if requested
    if (createShortcuts) {
      onStatusUpdate('Creating desktop shortcut...');
      try {
        await _platformLauncher.createDesktopShortcut();
        LoggingService.info('Desktop shortcut created successfully');
      } catch (e) {
        LoggingService.warning('Failed to create desktop shortcut', e);
      }
    }

    onProgress(1.0);
    onStatusUpdate('AppImage installation complete!');
  }

  /// Install archive by extracting and organizing files
  Future<void> _installArchive(
    String archivePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('Installing Linux archive');
    LoggingService.info('Archive path: $archivePath');

    Directory? extractTempDir;

    try {
      onStatusUpdate('Preparing installation...');
      onProgress(0.1);

      // Get install path and ensure it exists
      final installPath = await _installationService.getInstallPath();
      final installDir = Directory(installPath);
      if (!await installDir.exists()) {
        LoggingService.info('Creating install directory: $installPath');
        await installDir.create(recursive: true);
      }

      // Extract the archive to temp directory first
      onStatusUpdate('Extracting archive...');
      LoggingService.info('Creating extraction temp directory...');
      extractTempDir = await Directory.systemTemp.createTemp('eden_extract_');
      LoggingService.info('Extraction temp directory: ${extractTempDir.path}');

      LoggingService.info('Starting archive extraction...');
      await _extractionService.extractArchive(
        archivePath,
        extractTempDir.path,
        onProgress: (progress) {
          onProgress(0.1 + (progress * 0.5));
          onStatusUpdate('Extracting... ${(progress * 100).toInt()}%');
        },
      );
      LoggingService.info('Archive extraction completed');

      // Move extracted files to final location
      onStatusUpdate('Installing files...');
      LoggingService.info('Moving extracted files to install location...');
      await _moveExtractedFiles(extractTempDir.path, installPath);
      LoggingService.info('Files moved successfully');
      onProgress(0.7);

      // Organize the installation
      onStatusUpdate('Organizing installation...');
      LoggingService.info('Organizing installation structure...');
      await _installationService.organizeInstallation(installPath);
      LoggingService.info('Installation organized');

      // Make Eden executable files executable
      onStatusUpdate('Setting executable permissions...');
      await _makeExecutablesInDirectory(installPath);
      onProgress(0.8);

      // Update version info
      final channel = await _preferencesService.getReleaseChannel();
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);
      LoggingService.info(
        'Updated version info for channel $channel to ${updateInfo.version}',
      );

      // Create user folder for portable mode in the channel-specific folder
      if (portableMode) {
        onStatusUpdate('Setting up portable mode...');
        LoggingService.info('Setting up portable mode...');
        final channelInstallPath = await _installationService
            .getChannelInstallPath();
        final userPath = path.join(channelInstallPath, 'user');
        await Directory(userPath).create(recursive: true);
        LoggingService.info('Portable mode user directory created: $userPath');
      }
      onProgress(0.9);

      // Create shortcut if requested
      if (createShortcuts) {
        onStatusUpdate('Creating desktop shortcut...');
        try {
          await _platformLauncher.createDesktopShortcut();
          LoggingService.info('Desktop shortcut created successfully');
        } catch (e) {
          LoggingService.warning('Failed to create desktop shortcut', e);
        }
      }

      onProgress(1.0);
      onStatusUpdate('Installation complete!');
    } finally {
      // Clean up extraction temp directory
      if (extractTempDir != null && await extractTempDir.exists()) {
        try {
          await extractTempDir.delete(recursive: true);
          LoggingService.info('Cleaned up extraction temp directory');
        } catch (e) {
          LoggingService.warning(
            'Failed to clean up extraction temp directory',
            e,
          );
        }
      }
    }
  }

  /// Check if a file is an AppImage by examining its extension and content
  Future<bool> _isAppImageFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Check file extension first
      if (filePath.toLowerCase().endsWith('.appimage')) {
        LoggingService.info('File has .appimage extension');
        return true;
      }

      // Check if filename contains 'appimage' (case insensitive)
      final fileName = path.basename(filePath).toLowerCase();
      if (fileName.contains('appimage')) {
        LoggingService.info('File name contains "appimage"');
        return true;
      }

      // Enhanced AppImage detection: check file magic bytes
      try {
        final bytes = await file.openRead(0, 4).first;
        // AppImage files typically start with ELF magic bytes (0x7F, 'E', 'L', 'F')
        if (bytes.length >= 4 &&
            bytes[0] == 0x7F &&
            bytes[1] == 0x45 &&
            bytes[2] == 0x4C &&
            bytes[3] == 0x46) {
          LoggingService.info('File has ELF magic bytes, likely AppImage');
          return true;
        }
      } catch (e) {
        LoggingService.info('Could not read file magic bytes: $e');
      }

      return false;
    } catch (e) {
      LoggingService.error('Error checking if file is AppImage', e);
      return filePath.toLowerCase().endsWith('.appimage');
    }
  }

  /// Move extracted files from temp directory to install directory
  Future<void> _moveExtractedFiles(
    String extractPath,
    String installPath,
  ) async {
    final extractDir = Directory(extractPath);

    await for (final entity in extractDir.list()) {
      final targetPath = path.join(installPath, path.basename(entity.path));

      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await FileUtils.copyDirectory(entity.path, targetPath);
      }
    }
  }

  /// Make a file executable using chmod
  Future<void> _makeExecutable(String filePath) async {
    try {
      LoggingService.info('Making file executable: $filePath');
      final chmodResult = await Process.run('chmod', ['+x', filePath]);
      if (chmodResult.exitCode != 0) {
        LoggingService.warning(
          'Failed to set executable permissions: ${chmodResult.stderr}',
        );
        throw UpdateException(
          'Failed to set executable permissions',
          'chmod command failed: ${chmodResult.stderr}',
        );
      }
      LoggingService.info('File is now executable: $filePath');
    } catch (e) {
      LoggingService.error('Error making file executable', e);
      if (e is UpdateException) rethrow;
      throw UpdateException(
        'Failed to set executable permissions',
        e.toString(),
      );
    }
  }

  /// Make all Eden executable files in a directory executable
  Future<void> _makeExecutablesInDirectory(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final fileHandler = LinuxFileHandler();
          if (fileHandler.isEdenExecutable(fileName)) {
            await _makeExecutable(entity.path);
          }
        }
      }
    } catch (e) {
      LoggingService.error('Error making executables in directory', e);
      // Don't throw as this is not critical for the installation
    }
  }

  /// Find Eden executable in the installation directory
  Future<String?> _findEdenExecutableInDirectory(String installPath) async {
    try {
      final installDir = Directory(installPath);

      await for (final entity in installDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final fileHandler = LinuxFileHandler();
          if (fileHandler.isEdenExecutable(fileName)) {
            return entity.path;
          }
        }
      }

      return null;
    } catch (e) {
      LoggingService.error('Error searching for Eden executable', e);
      return null;
    }
  }
}
