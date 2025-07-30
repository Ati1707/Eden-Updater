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
import '../windows/windows_launcher.dart';
import 'windows_file_handler.dart';

/// Windows-specific installer implementation
class WindowsInstaller implements IPlatformInstaller {
  final ExtractionService _extractionService;
  final InstallationService _installationService;
  final PreferencesService _preferencesService;
  final IPlatformLauncher _platformLauncher;

  WindowsInstaller(
    this._extractionService,
    this._installationService,
    this._preferencesService,
  ) : _platformLauncher = WindowsLauncher(
        _preferencesService,
        _installationService,
      );

  @override
  Future<bool> canHandle(String filePath) async {
    try {
      LoggingService.debug(
        '[Windows] Checking if installer can handle file: $filePath',
      );

      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('[Windows] File does not exist: $filePath');
        return false;
      }

      // Windows installer handles archive files (zip, 7z, tar.gz, etc.)
      // but not APK or AppImage files
      final extension = path.extension(filePath).toLowerCase();
      final fileName = path.basename(filePath).toLowerCase();

      LoggingService.debug(
        '[Windows] File extension: $extension, filename: $fileName',
      );

      // Explicitly reject unsupported formats first
      if (extension == '.apk' || extension == '.appimage') {
        LoggingService.debug(
          '[Windows] Rejecting unsupported format: $extension',
        );
        return false;
      }

      // Check for compound extensions like .tar.gz first
      if (fileName.endsWith('.tar.gz') ||
          fileName.endsWith('.tar.bz2') ||
          fileName.endsWith('.tar.xz')) {
        LoggingService.debug(
          '[Windows] Accepting compound archive format: $fileName',
        );
        return true;
      }

      // Supported single extensions for Windows
      final supportedExtensions = [
        '.zip',
        '.7z',
        '.rar',
        '.tar',
        '.gz',
        '.bz2',
        '.xz',
      ];

      // Check if it's a supported archive format
      final canHandle = supportedExtensions.contains(extension);
      LoggingService.debug(
        '[Windows] Can handle file: $canHandle (extension: $extension)',
      );
      return canHandle;
    } catch (e) {
      LoggingService.error(
        '[Windows] Error checking if installer can handle file: $filePath',
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
    LoggingService.info('[Windows] Starting installation operation');
    LoggingService.info('[Windows] File path: $filePath');
    LoggingService.info('[Windows] Update version: ${updateInfo.version}');
    LoggingService.info('[Windows] Create shortcuts: $createShortcuts');
    LoggingService.info('[Windows] Portable mode: $portableMode');
    LoggingService.debug(
      '[Windows] Platform: Windows ${Platform.operatingSystemVersion}',
    );

    Directory? extractTempDir;

    try {
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw UpdateException('Installation file not found', filePath);
      }

      onStatusUpdate('Preparing installation...');
      onProgress(0.1);

      // Get install path and ensure it exists
      final installPath = await _installationService.getInstallPath();
      final installDir = Directory(installPath);
      if (!await installDir.exists()) {
        LoggingService.info(
          '[Windows] Creating install directory: $installPath',
        );
        await installDir.create(recursive: true);
      }

      // Extract the archive to temp directory first
      onStatusUpdate('Extracting archive...');
      LoggingService.info('[Windows] Creating extraction temp directory...');
      extractTempDir = await Directory.systemTemp.createTemp('eden_extract_');
      LoggingService.info(
        '[Windows] Extraction temp directory: ${extractTempDir.path}',
      );

      LoggingService.info('[Windows] Starting archive extraction...');
      await _extractionService.extractArchive(
        filePath,
        extractTempDir.path,
        onProgress: (progress) {
          onProgress(0.1 + (progress * 0.5));
          onStatusUpdate('Extracting... ${(progress * 100).toInt()}%');
        },
      );
      LoggingService.info('[Windows] Archive extraction completed');

      // Move extracted files to final location
      onStatusUpdate('Installing files...');
      LoggingService.info(
        '[Windows] Moving extracted files to install location...',
      );
      await _moveExtractedFiles(extractTempDir.path, installPath);
      LoggingService.info('[Windows] Files moved successfully');
      onProgress(0.7);

      // Organize the installation
      onStatusUpdate('Organizing installation...');
      LoggingService.info('[Windows] Organizing installation structure...');
      await _installationService.organizeInstallation(installPath);
      LoggingService.info('[Windows] Installation organized');
      onProgress(0.8);

      // Update version info
      final channel = await _preferencesService.getReleaseChannel();
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);
      LoggingService.info(
        '[Windows] Updated version info for channel $channel to ${updateInfo.version}',
      );

      // Create user folder for portable mode in the channel-specific folder
      if (portableMode) {
        onStatusUpdate('Setting up portable mode...');
        LoggingService.info('[Windows] Setting up portable mode...');
        final channelInstallPath = await _installationService
            .getChannelInstallPath();
        final userPath = path.join(channelInstallPath, 'user');
        await Directory(userPath).create(recursive: true);
        LoggingService.info(
          '[Windows] Portable mode user directory created: $userPath',
        );
      }
      onProgress(0.9);

      // Create shortcut if requested
      if (createShortcuts) {
        onStatusUpdate('Creating desktop shortcut...');
        try {
          LoggingService.debug(
            '[Windows] Attempting to create desktop shortcut...',
          );
          await _platformLauncher.createDesktopShortcut();
          LoggingService.info(
            '[Windows] Desktop shortcut created successfully',
          );
        } catch (e) {
          LoggingService.warning(
            '[Windows] Failed to create desktop shortcut',
            e,
          );
        }
      }

      onProgress(1.0);
      onStatusUpdate('Installation complete!');
      LoggingService.info(
        '[Windows] Installation operation completed successfully',
      );
    } catch (e) {
      LoggingService.error('[Windows] Installation operation failed', e);
      if (e is AppException) {
        rethrow;
      }
      throw UpdateException('Windows installation failed', e.toString());
    } finally {
      // Clean up extraction temp directory
      if (extractTempDir != null && await extractTempDir.exists()) {
        try {
          await extractTempDir.delete(recursive: true);
          LoggingService.info('[Windows] Cleaned up extraction temp directory');
        } catch (e) {
          LoggingService.warning(
            '[Windows] Failed to clean up extraction temp directory',
            e,
          );
        }
      }
    }
  }

  @override
  Future<void> postInstallSetup(
    String installPath,
    UpdateInfo updateInfo,
  ) async {
    LoggingService.info('[Windows] Performing post-install setup');
    LoggingService.debug('[Windows] Install path: $installPath');
    LoggingService.debug('[Windows] Update version: ${updateInfo.version}');

    try {
      // Find and verify the Eden executable exists
      final channel = await _preferencesService.getReleaseChannel();
      LoggingService.debug('[Windows] Channel: $channel');

      final fileHandler = WindowsFileHandler();
      final expectedExecutablePath = fileHandler.getEdenExecutablePath(
        installPath,
        channel,
      );

      LoggingService.debug(
        '[Windows] Expected executable path: $expectedExecutablePath',
      );

      if (await File(expectedExecutablePath).exists()) {
        // Store the executable path for future launches
        await _preferencesService.setEdenExecutablePath(
          channel,
          expectedExecutablePath,
        );
        LoggingService.info(
          '[Windows] Stored Eden executable path: $expectedExecutablePath',
        );
      } else {
        LoggingService.warning(
          '[Windows] Eden executable not found at expected path: $expectedExecutablePath',
        );

        // Try to find the executable in the installation directory
        LoggingService.debug(
          '[Windows] Searching for Eden executable in installation directory...',
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
            '[Windows] Found and stored Eden executable path: $foundExecutable',
          );
        } else {
          LoggingService.error(
            '[Windows] Could not find Eden executable in installation directory',
          );
        }
      }
    } catch (e) {
      LoggingService.error('[Windows] Error during post-install setup', e);
      // Don't throw here as the main installation was successful
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

  /// Find Eden executable in the installation directory
  Future<String?> _findEdenExecutableInDirectory(String installPath) async {
    try {
      final installDir = Directory(installPath);

      await for (final entity in installDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final fileHandler = WindowsFileHandler();
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
