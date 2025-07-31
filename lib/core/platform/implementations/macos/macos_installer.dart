import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_installer.dart';
import '../../../../models/update_info.dart';
import '../../../errors/app_exceptions.dart';
import '../../../services/logging_service.dart';
import '../../../../services/extraction/extraction_service.dart';
import '../../../../services/storage/preferences_service.dart';
import 'macos_file_handler.dart';

/// macOS-specific installer implementation
class MacOSInstaller implements IPlatformInstaller {
  final ExtractionService _extractionService;
  final PreferencesService _preferencesService;

  MacOSInstaller(this._extractionService, this._preferencesService);

  @override
  Future<bool> canHandle(String filePath) async {
    try {
      LoggingService.debug(
        '[macOS] Checking if installer can handle file: $filePath',
      );

      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.debug('[macOS] File does not exist: $filePath');
        return false;
      }

      final extension = path.extension(filePath).toLowerCase();
      final fileName = path.basename(filePath).toLowerCase();

      LoggingService.debug(
        '[macOS] File extension: $extension, filename: $fileName',
      );

      // Check for DMG files
      if (extension == '.dmg') {
        LoggingService.debug('[macOS] Accepting DMG file: $fileName');
        return true;
      }

      // Check for .app bundles
      if (extension == '.app' && fileName.contains('eden')) {
        LoggingService.debug('[macOS] Accepting .app bundle: $fileName');
        return true;
      }

      // Supported archive formats for macOS
      final supportedExtensions = ['.zip', '.tar', '.gz', '.bz2', '.xz'];

      // Check if it's a supported archive format
      if (supportedExtensions.any((ext) => extension.endsWith(ext))) {
        LoggingService.debug('[macOS] Accepting archive format: $extension');
        return true;
      }

      // Check for compound extensions like .tar.gz, .tar.bz2, .tar.xz
      if (fileName.endsWith('.tar.gz') ||
          fileName.endsWith('.tar.bz2') ||
          fileName.endsWith('.tar.xz')) {
        LoggingService.debug(
          '[macOS] Accepting compound archive format: $fileName',
        );
        return true;
      }

      // Reject APK files (not supported on macOS)
      if (extension == '.apk') {
        LoggingService.debug('[macOS] Rejecting APK file: $extension');
        return false;
      }

      LoggingService.debug('[macOS] Cannot handle file: $filePath');
      return false;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error checking if installer can handle file: $filePath',
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
    LoggingService.info('[macOS] Starting installation operation');
    LoggingService.info('[macOS] File path: $filePath');
    LoggingService.info('[macOS] Update version: ${updateInfo.version}');
    LoggingService.info('[macOS] Create shortcuts: $createShortcuts');
    LoggingService.info('[macOS] Portable mode: $portableMode');
    LoggingService.debug(
      '[macOS] Platform: macOS ${Platform.operatingSystemVersion}',
    );

    try {
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.error('[macOS] Installation file not found: $filePath');
        throw UpdateException('Installation file not found', filePath);
      }

      // Determine installation method based on file type
      LoggingService.debug('[macOS] Determining installation method...');
      if (await _isDMGFile(filePath)) {
        LoggingService.info('[macOS] Installing from DMG');
        await _installFromDMG(
          filePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      } else if (await _isAppBundle(filePath)) {
        LoggingService.info('[macOS] Installing .app bundle');
        await _installAppBundle(
          filePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      } else {
        LoggingService.info('[macOS] Installing from archive');
        await _installFromArchive(
          filePath,
          updateInfo,
          createShortcuts: createShortcuts,
          portableMode: portableMode,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      }

      LoggingService.info('[macOS] Installation completed successfully');
    } catch (e) {
      LoggingService.error('[macOS] Installation failed', e);
      rethrow;
    }
  }

  @override
  Future<void> postInstallSetup(
    String installPath,
    UpdateInfo updateInfo,
  ) async {
    LoggingService.info('[macOS] Starting post-install setup');
    LoggingService.info('[macOS] Install path: $installPath');

    try {
      // Set executable permissions for Eden binary
      final channel = await _preferencesService.getReleaseChannel();
      await _setExecutablePermissions(installPath, channel);

      LoggingService.info('[macOS] Post-install setup completed successfully');
    } catch (e) {
      LoggingService.error('[macOS] Post-install setup failed', e);
      rethrow;
    }
  }

  /// Check if a file is a DMG disk image
  Future<bool> _isDMGFile(String filePath) async {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.dmg';
  }

  /// Check if a file is an .app bundle
  Future<bool> _isAppBundle(String filePath) async {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.app' && await Directory(filePath).exists();
  }

  /// Install from DMG file
  Future<void> _installFromDMG(
    String dmgPath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('[macOS] Installing from DMG: $dmgPath');
    onStatusUpdate('Mounting DMG...');
    onProgress(0.1);

    String? mountPoint;
    try {
      // Mount the DMG
      mountPoint = await _mountDMG(dmgPath);
      onProgress(0.3);

      // Find Eden app in mounted DMG
      onStatusUpdate('Finding Eden application...');
      final edenAppPath = await _findEdenAppInMount(mountPoint);
      if (edenAppPath == null) {
        throw UpdateException('Eden application not found in DMG', dmgPath);
      }
      onProgress(0.5);

      // Copy Eden app to installation directory
      onStatusUpdate('Copying application...');
      final channel = await _preferencesService.getReleaseChannel();
      final installDir = await _getInstallationDirectory(channel);
      final targetPath = path.join(installDir, path.basename(edenAppPath));

      await _copyAppBundle(edenAppPath, targetPath);
      onProgress(0.9);

      // Post-install setup
      await postInstallSetup(installDir, updateInfo);
      onProgress(1.0);
    } finally {
      // Always unmount the DMG
      if (mountPoint != null) {
        await _unmountDMG(mountPoint);
      }
    }
  }

  /// Install .app bundle directly
  Future<void> _installAppBundle(
    String appPath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('[macOS] Installing .app bundle: $appPath');
    onStatusUpdate('Copying application...');
    onProgress(0.2);

    final channel = await _preferencesService.getReleaseChannel();
    final installDir = await _getInstallationDirectory(channel);
    final targetPath = path.join(installDir, path.basename(appPath));

    await _copyAppBundle(appPath, targetPath);
    onProgress(0.8);

    // Post-install setup
    await postInstallSetup(installDir, updateInfo);
    onProgress(1.0);
  }

  /// Install from archive (ZIP, tar.gz, etc.)
  Future<void> _installFromArchive(
    String archivePath,
    UpdateInfo updateInfo, {
    required bool createShortcuts,
    required bool portableMode,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('[macOS] Installing from archive: $archivePath');
    onStatusUpdate('Extracting archive...');
    onProgress(0.2);

    final channel = await _preferencesService.getReleaseChannel();
    final installDir = await _getInstallationDirectory(channel);

    // Extract archive to installation directory
    await _extractionService.extractArchive(
      archivePath,
      installDir,
      onProgress: (progress) => onProgress(0.2 + (progress * 0.6)),
    );
    onProgress(0.8);

    // Post-install setup
    await postInstallSetup(installDir, updateInfo);
    onProgress(1.0);
  }

  /// Mount a DMG file and return the mount point
  Future<String> _mountDMG(String dmgPath) async {
    LoggingService.info('[macOS] Mounting DMG: $dmgPath');

    final result = await Process.run('hdiutil', [
      'attach',
      dmgPath,
      '-nobrowse',
      '-quiet',
    ]);

    if (result.exitCode != 0) {
      LoggingService.error('[macOS] Failed to mount DMG: ${result.stderr}');
      throw UpdateException('Failed to mount DMG', dmgPath);
    }

    // Parse mount point from output
    final output = result.stdout.toString();
    final lines = output.split('\n');
    for (final line in lines) {
      if (line.contains('/Volumes/')) {
        final parts = line.split('\t');
        for (final part in parts) {
          if (part.trim().startsWith('/Volumes/')) {
            final mountPoint = part.trim();
            LoggingService.info('[macOS] DMG mounted at: $mountPoint');
            return mountPoint;
          }
        }
      }
    }

    throw UpdateException('Could not determine mount point for DMG', dmgPath);
  }

  /// Unmount a DMG
  Future<void> _unmountDMG(String mountPoint) async {
    LoggingService.info('[macOS] Unmounting DMG: $mountPoint');

    try {
      final result = await Process.run('hdiutil', [
        'detach',
        mountPoint,
        '-quiet',
      ]);

      if (result.exitCode != 0) {
        LoggingService.warning(
          '[macOS] Failed to unmount DMG cleanly: ${result.stderr}',
        );
      } else {
        LoggingService.info('[macOS] DMG unmounted successfully');
      }
    } catch (e) {
      LoggingService.warning('[macOS] Error unmounting DMG', e);
    }
  }

  /// Find Eden app in mounted DMG
  Future<String?> _findEdenAppInMount(String mountPoint) async {
    LoggingService.info('[macOS] Searching for Eden app in: $mountPoint');

    try {
      final mountDir = Directory(mountPoint);
      await for (final entity in mountDir.list()) {
        if (entity is Directory && entity.path.endsWith('.app')) {
          final appName = path.basename(entity.path).toLowerCase();
          if (appName.contains('eden')) {
            LoggingService.info('[macOS] Found Eden app: ${entity.path}');
            return entity.path;
          }
        }
      }
    } catch (e) {
      LoggingService.error('[macOS] Error searching for Eden app', e);
    }

    return null;
  }

  /// Copy .app bundle from source to target
  Future<void> _copyAppBundle(String sourcePath, String targetPath) async {
    LoggingService.info(
      '[macOS] Copying app bundle: $sourcePath -> $targetPath',
    );

    try {
      // Remove target if it exists
      final targetDir = Directory(targetPath);
      if (await targetDir.exists()) {
        LoggingService.info('[macOS] Removing existing app bundle');
        await targetDir.delete(recursive: true);
      }

      // Use cp -R to copy the entire .app bundle
      final result = await Process.run('cp', ['-R', sourcePath, targetPath]);

      if (result.exitCode != 0) {
        LoggingService.error(
          '[macOS] Failed to copy app bundle: ${result.stderr}',
        );
        throw UpdateException('Failed to copy app bundle', sourcePath);
      }

      LoggingService.info('[macOS] App bundle copied successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error copying app bundle', e);
      rethrow;
    }
  }

  /// Get installation directory for channel
  Future<String> _getInstallationDirectory(String channel) async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      throw UpdateException('HOME environment variable not found', '');
    }

    final baseDir = path.join(homeDir, 'Documents', 'Eden');
    final channelDir = channel == 'nightly' ? 'Eden-Nightly' : 'Eden-Release';
    final installDir = path.join(baseDir, channelDir);

    // Ensure directory exists
    await Directory(installDir).create(recursive: true);

    return installDir;
  }

  /// Set executable permissions for Eden binary
  Future<void> _setExecutablePermissions(
    String installPath,
    String channel,
  ) async {
    LoggingService.info('[macOS] Setting executable permissions');

    try {
      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installPath, channel);

      if (await File(edenPath).exists()) {
        await fileHandler.makeExecutable(edenPath);
        LoggingService.info(
          '[macOS] Executable permissions set for: $edenPath',
        );
      } else {
        LoggingService.warning('[macOS] Eden executable not found: $edenPath');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error setting executable permissions', e);
      // Don't rethrow as this is not critical
    }
  }
}
