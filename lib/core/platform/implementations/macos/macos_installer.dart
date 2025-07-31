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

  // Temporary storage for installation session data
  bool _currentPortableMode = false;

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

    String? installDir;
    try {
      // Initial progress
      onProgress(0.0);
      onStatusUpdate('Preparing installation...');

      // Verify file exists and is accessible
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService.error('[macOS] Installation file not found: $filePath');
        throw UpdateException('Installation file not found', filePath);
      }

      // Verify file is readable
      try {
        await file.readAsBytes();
      } catch (e) {
        LoggingService.error(
          '[macOS] Cannot read installation file: $filePath',
        );
        throw UpdateException('Cannot read installation file', filePath);
      }

      // Store session data for use in postInstallSetup
      _currentPortableMode = portableMode;

      // Get installation directory early for cleanup purposes
      final channel = await _preferencesService.getReleaseChannel();
      installDir = await _getInstallationDirectory(channel);

      // Determine installation method based on file type
      LoggingService.debug('[macOS] Determining installation method...');
      onProgress(0.05);

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

      // Final verification
      onStatusUpdate('Verifying installation...');
      await _verifyInstallation(installDir, updateInfo);
      onProgress(1.0);

      LoggingService.info('[macOS] Installation completed successfully');
    } catch (e) {
      LoggingService.error('[macOS] Installation failed', e);

      // Attempt cleanup on failure
      if (installDir != null) {
        await _cleanupFailedInstallation(installDir);
      }

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
      final channel = await _preferencesService.getReleaseChannel();

      // Set executable permissions for Eden binary
      await _setExecutablePermissions(installPath, channel);

      // Create portable mode directory if needed
      if (_currentPortableMode) {
        await _createPortableModeDirectory(installPath);
      }

      // Validate installation structure
      await _validateInstallationStructure(installPath);

      // Store installation metadata
      await _storeInstallationMetadata(installPath, updateInfo);

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

    // Validate DMG file first
    onStatusUpdate('Validating DMG file...');
    onProgress(0.05);

    if (!await _validateDMGFile(dmgPath)) {
      throw UpdateException('Invalid or corrupted DMG file', dmgPath);
    }

    String? mountPoint;
    String? installDir;

    try {
      // Mount the DMG
      onStatusUpdate('Mounting DMG...');
      onProgress(0.1);
      mountPoint = await _mountDMG(dmgPath);
      LoggingService.info('[macOS] DMG mounted successfully at: $mountPoint');
      onProgress(0.25);

      // Find Eden app in mounted DMG
      onStatusUpdate('Searching for Eden application...');
      final edenAppPath = await _findEdenAppInMount(mountPoint);
      if (edenAppPath == null) {
        throw UpdateException('Eden application not found in DMG', dmgPath);
      }
      LoggingService.info('[macOS] Found Eden app: $edenAppPath');
      onProgress(0.4);

      // Validate the found app bundle
      onStatusUpdate('Validating application bundle...');
      if (!await _validateAppBundle(edenAppPath)) {
        throw UpdateException(
          'Invalid Eden application bundle in DMG',
          edenAppPath,
        );
      }
      onProgress(0.5);

      // Prepare installation directory
      onStatusUpdate('Preparing installation directory...');
      final channel = await _preferencesService.getReleaseChannel();
      installDir = await _getInstallationDirectory(channel);
      final targetPath = path.join(installDir, path.basename(edenAppPath));
      onProgress(0.6);

      // Copy Eden app to installation directory
      onStatusUpdate('Copying application...');
      await _copyAppBundle(edenAppPath, targetPath);
      LoggingService.info('[macOS] App bundle copied to: $targetPath');
      onProgress(0.85);

      // Post-install setup
      onStatusUpdate('Completing installation...');
      await postInstallSetup(installDir, updateInfo);
      onProgress(0.95);

      onStatusUpdate('Installation completed');
      onProgress(1.0);
    } catch (e) {
      LoggingService.error('[macOS] DMG installation failed', e);

      // Clean up on failure
      if (installDir != null) {
        await _cleanupFailedInstallation(installDir);
      }

      rethrow;
    } finally {
      // Always unmount the DMG, even on failure
      if (mountPoint != null) {
        onStatusUpdate('Unmounting DMG...');
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

    String? installDir;
    String? targetPath;

    try {
      // Validate the source app bundle
      onStatusUpdate('Validating application bundle...');
      onProgress(0.1);

      if (!await _validateAppBundle(appPath)) {
        throw UpdateException('Invalid .app bundle structure', appPath);
      }

      // Prepare installation directory
      onStatusUpdate('Preparing installation directory...');
      onProgress(0.2);

      final channel = await _preferencesService.getReleaseChannel();
      installDir = await _getInstallationDirectory(channel);
      targetPath = path.join(installDir, path.basename(appPath));

      // Check available disk space
      onStatusUpdate('Checking disk space...');
      await _checkDiskSpace(appPath, installDir);
      onProgress(0.3);

      // Remove existing installation if present
      onStatusUpdate('Removing previous installation...');
      await _removeExistingInstallation(targetPath);
      onProgress(0.4);

      // Copy the app bundle with progress tracking
      onStatusUpdate('Copying application bundle...');
      await _copyAppBundleWithProgress(
        appPath,
        targetPath,
        (progress) => onProgress(0.4 + (progress * 0.4)), // 0.4 to 0.8
      );
      onProgress(0.8);

      // Verify the copied bundle
      onStatusUpdate('Verifying installation...');
      if (!await _validateAppBundle(targetPath)) {
        throw UpdateException('Copied app bundle is invalid', targetPath);
      }
      onProgress(0.9);

      // Post-install setup
      onStatusUpdate('Completing installation...');
      await postInstallSetup(installDir, updateInfo);
      onProgress(0.95);

      onStatusUpdate('Installation completed');
      onProgress(1.0);
    } catch (e) {
      LoggingService.error('[macOS] App bundle installation failed', e);

      // Clean up on failure
      if (targetPath != null && await Directory(targetPath).exists()) {
        try {
          await Directory(targetPath).delete(recursive: true);
          LoggingService.info(
            '[macOS] Cleaned up failed app bundle installation',
          );
        } catch (cleanupError) {
          LoggingService.warning(
            '[macOS] Failed to cleanup after error',
            cleanupError,
          );
        }
      }

      rethrow;
    }
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

    String? installDir;

    try {
      // Validate archive file
      onStatusUpdate('Validating archive...');
      onProgress(0.05);

      if (!await _validateArchiveFile(archivePath)) {
        throw UpdateException('Invalid or corrupted archive file', archivePath);
      }

      // Prepare installation directory
      onStatusUpdate('Preparing installation directory...');
      onProgress(0.1);

      final channel = await _preferencesService.getReleaseChannel();
      installDir = await _getInstallationDirectory(channel);

      // Check disk space
      await _checkArchiveDiskSpace(archivePath, installDir);
      onProgress(0.15);

      // Clean existing installation
      onStatusUpdate('Cleaning previous installation...');
      await _cleanInstallationDirectory(installDir);
      onProgress(0.2);

      // Extract archive to installation directory with progress tracking
      onStatusUpdate('Extracting archive...');
      await _extractionService.extractArchive(
        archivePath,
        installDir,
        onProgress: (progress) {
          final adjustedProgress = 0.2 + (progress * 0.5); // 0.2 to 0.7
          onProgress(adjustedProgress);
          if (progress < 1.0) {
            onStatusUpdate(
              'Extracting archive... ${(progress * 100).toInt()}%',
            );
          }
        },
      );
      onProgress(0.7);

      // Verify extraction was successful
      onStatusUpdate('Verifying extraction...');
      await _verifyArchiveExtraction(installDir);
      onProgress(0.75);

      // Set executable permissions for all extracted files
      onStatusUpdate('Setting file permissions...');
      await _setArchivePermissions(installDir);
      onProgress(0.85);

      // Post-install setup
      onStatusUpdate('Completing installation...');
      await postInstallSetup(installDir, updateInfo);
      onProgress(0.95);

      onStatusUpdate('Installation completed');
      onProgress(1.0);
    } catch (e) {
      LoggingService.error('[macOS] Archive installation failed', e);

      // Clean up on failure
      if (installDir != null) {
        await _cleanupFailedInstallation(installDir);
      }

      rethrow;
    }
  }

  /// Mount a DMG file and return the mount point
  Future<String> _mountDMG(String dmgPath) async {
    LoggingService.info('[macOS] Mounting DMG: $dmgPath');

    try {
      // First verify the DMG file exists and is readable
      final dmgFile = File(dmgPath);
      if (!await dmgFile.exists()) {
        throw UpdateException('DMG file does not exist', dmgPath);
      }

      // Try to mount with multiple strategies for better compatibility
      ProcessResult result;

      // Strategy 1: Standard mount with no browse and quiet
      result = await Process.run('hdiutil', [
        'attach',
        dmgPath,
        '-nobrowse',
        '-quiet',
        '-readonly',
      ]);

      // Strategy 2: If first attempt fails, try without readonly flag
      if (result.exitCode != 0) {
        LoggingService.warning(
          '[macOS] First mount attempt failed, trying without readonly',
        );
        result = await Process.run('hdiutil', [
          'attach',
          dmgPath,
          '-nobrowse',
          '-quiet',
        ]);
      }

      // Strategy 3: If still failing, try with verbose output for debugging
      if (result.exitCode != 0) {
        LoggingService.warning(
          '[macOS] Second mount attempt failed, trying with verbose output',
        );
        result = await Process.run('hdiutil', ['attach', dmgPath, '-nobrowse']);
      }

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();
        LoggingService.error('[macOS] All DMG mount attempts failed');
        LoggingService.error('[macOS] stderr: $stderr');
        LoggingService.error('[macOS] stdout: $stdout');
        throw UpdateException('Failed to mount DMG: $stderr', dmgPath);
      }

      // Parse mount point from output
      final output = result.stdout.toString();
      final mountPoint = _parseMountPointFromOutput(output);

      if (mountPoint == null) {
        throw UpdateException(
          'Could not determine mount point for DMG',
          dmgPath,
        );
      }

      // Verify mount point exists and is accessible
      final mountDir = Directory(mountPoint);
      if (!await mountDir.exists()) {
        throw UpdateException(
          'Mount point does not exist: $mountPoint',
          dmgPath,
        );
      }

      LoggingService.info('[macOS] DMG mounted successfully at: $mountPoint');
      return mountPoint;
    } catch (e) {
      LoggingService.error('[macOS] Error mounting DMG: $dmgPath', e);
      rethrow;
    }
  }

  /// Parse mount point from hdiutil output
  String? _parseMountPointFromOutput(String output) {
    final lines = output.split('\n');

    // Look for lines containing /Volumes/
    for (final line in lines) {
      if (line.contains('/Volumes/')) {
        // Split by tabs and find the volume path
        final parts = line.split('\t');
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('/Volumes/')) {
            LoggingService.debug('[macOS] Parsed mount point: $trimmed');
            return trimmed;
          }
        }

        // Alternative parsing: look for /Volumes/ anywhere in the line
        final volumesIndex = line.indexOf('/Volumes/');
        if (volumesIndex != -1) {
          // Extract from /Volumes/ to the end of the path
          final volumePath = line.substring(volumesIndex).trim();
          // Remove any trailing whitespace or additional text
          final cleanPath = volumePath.split(RegExp(r'\s+'))[0];
          LoggingService.debug(
            '[macOS] Alternative parsed mount point: $cleanPath',
          );
          return cleanPath;
        }
      }
    }

    LoggingService.warning(
      '[macOS] Could not parse mount point from output: $output',
    );
    return null;
  }

  /// Unmount a DMG with retry logic
  Future<void> _unmountDMG(String mountPoint) async {
    LoggingService.info('[macOS] Unmounting DMG: $mountPoint');

    try {
      // Verify mount point exists before attempting unmount
      final mountDir = Directory(mountPoint);
      if (!await mountDir.exists()) {
        LoggingService.info(
          '[macOS] Mount point no longer exists, assuming already unmounted',
        );
        return;
      }

      // Strategy 1: Standard quiet unmount
      var result = await Process.run('hdiutil', [
        'detach',
        mountPoint,
        '-quiet',
      ]);

      // Strategy 2: If failed, try with force flag
      if (result.exitCode != 0) {
        LoggingService.warning(
          '[macOS] Standard unmount failed, trying with force',
        );
        await Future.delayed(const Duration(seconds: 1)); // Brief delay

        result = await Process.run('hdiutil', [
          'detach',
          mountPoint,
          '-force',
          '-quiet',
        ]);
      }

      // Strategy 3: If still failed, try without quiet for error details
      if (result.exitCode != 0) {
        LoggingService.warning('[macOS] Force unmount failed, trying verbose');
        await Future.delayed(const Duration(seconds: 2)); // Longer delay

        result = await Process.run('hdiutil', ['detach', mountPoint, '-force']);
      }

      if (result.exitCode == 0) {
        LoggingService.info('[macOS] DMG unmounted successfully');

        // Verify the mount point is actually gone
        await Future.delayed(const Duration(milliseconds: 500));
        if (await mountDir.exists()) {
          LoggingService.warning(
            '[macOS] Mount point still exists after unmount',
          );
        }
      } else {
        final stderr = result.stderr.toString().trim();
        LoggingService.warning('[macOS] All unmount attempts failed: $stderr');

        // Don't throw here as unmount failures shouldn't break the installation
        // The system will eventually clean up the mount point
      }
    } catch (e) {
      LoggingService.warning('[macOS] Error during DMG unmount', e);
      // Don't rethrow unmount errors as they're not critical
    }
  }

  /// Find Eden app in mounted DMG with comprehensive search
  Future<String?> _findEdenAppInMount(String mountPoint) async {
    LoggingService.info('[macOS] Searching for Eden app in: $mountPoint');

    try {
      final mountDir = Directory(mountPoint);
      if (!await mountDir.exists()) {
        LoggingService.error('[macOS] Mount point does not exist: $mountPoint');
        return null;
      }

      final foundApps = <String>[];

      // Search for .app bundles recursively (but not too deep)
      await _searchForEdenApps(mountDir, foundApps, 0, 3);

      if (foundApps.isEmpty) {
        LoggingService.warning('[macOS] No Eden .app bundles found in DMG');
        return null;
      }

      // If multiple apps found, prefer the most likely candidate
      final bestApp = _selectBestEdenApp(foundApps);
      LoggingService.info('[macOS] Selected Eden app: $bestApp');

      return bestApp;
    } catch (e) {
      LoggingService.error('[macOS] Error searching for Eden app', e);
      return null;
    }
  }

  /// Recursively search for Eden .app bundles
  Future<void> _searchForEdenApps(
    Directory dir,
    List<String> foundApps,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth > maxDepth) {
      return;
    }

    try {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final entityName = path.basename(entity.path).toLowerCase();

          // Check if this is an .app bundle
          if (entity.path.endsWith('.app')) {
            if (_isLikelyEdenApp(entityName)) {
              LoggingService.info(
                '[macOS] Found potential Eden app: ${entity.path}',
              );
              foundApps.add(entity.path);
            }
          } else {
            // Continue searching in subdirectories
            await _searchForEdenApps(
              entity,
              foundApps,
              currentDepth + 1,
              maxDepth,
            );
          }
        }
      }
    } catch (e) {
      LoggingService.warning(
        '[macOS] Error searching directory: ${dir.path}',
        e,
      );
    }
  }

  /// Check if an app name is likely to be Eden
  bool _isLikelyEdenApp(String appName) {
    final name = appName.toLowerCase();

    // Direct matches
    if (name == 'eden.app' ||
        name == 'eden-nightly.app' ||
        name == 'eden-stable.app') {
      return true;
    }

    // Contains eden
    if (name.contains('eden')) {
      return true;
    }

    // Common variations
    if (name.contains('emulator') && name.contains('eden')) {
      return true;
    }

    return false;
  }

  /// Select the best Eden app from multiple candidates
  String _selectBestEdenApp(List<String> apps) {
    if (apps.length == 1) {
      return apps.first;
    }

    // Scoring system for app selection
    String bestApp = apps.first;
    int bestScore = 0;

    for (final app in apps) {
      final name = path.basename(app).toLowerCase();
      int score = 0;

      // Exact matches get highest score
      if (name == 'eden.app') score += 100;
      if (name == 'eden-nightly.app') score += 90;
      if (name == 'eden-stable.app') score += 90;

      // Prefer shorter names (less likely to be nested or modified)
      score += (50 - name.length.clamp(0, 50));

      // Prefer apps in root of mount point
      final pathDepth = app.split('/').length;
      score += (20 - pathDepth.clamp(0, 20));

      LoggingService.debug('[macOS] App candidate: $app, score: $score');

      if (score > bestScore) {
        bestScore = score;
        bestApp = app;
      }
    }

    LoggingService.info('[macOS] Best Eden app (score $bestScore): $bestApp');
    return bestApp;
  }

  /// Copy .app bundle from source to target (legacy method for DMG installation)
  Future<void> _copyAppBundle(String sourcePath, String targetPath) async {
    await _copyAppBundleWithProgress(sourcePath, targetPath, (_) {});
  }

  /// Copy .app bundle with progress tracking
  Future<void> _copyAppBundleWithProgress(
    String sourcePath,
    String targetPath,
    Function(double) onProgress,
  ) async {
    LoggingService.info(
      '[macOS] Copying app bundle: $sourcePath -> $targetPath',
    );

    try {
      onProgress(0.0);

      // Ensure parent directory exists
      final parentDir = Directory(path.dirname(targetPath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Remove target if it exists
      final targetDir = Directory(targetPath);
      if (await targetDir.exists()) {
        LoggingService.info('[macOS] Removing existing app bundle');
        await targetDir.delete(recursive: true);
      }
      onProgress(0.1);

      // Use cp -R to copy the entire .app bundle with preservation of attributes
      final result = await Process.run('cp', [
        '-R',
        '-p', // Preserve attributes (timestamps, permissions)
        sourcePath,
        targetPath,
      ]);

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        LoggingService.error('[macOS] Failed to copy app bundle: $stderr');
        throw UpdateException('Failed to copy app bundle: $stderr', sourcePath);
      }
      onProgress(0.8);

      // Verify the copy was successful
      if (!await Directory(targetPath).exists()) {
        throw UpdateException(
          'App bundle copy failed - target does not exist',
          targetPath,
        );
      }
      onProgress(0.9);

      // Set proper permissions on the copied bundle
      await _setAppBundlePermissions(targetPath);
      onProgress(1.0);

      LoggingService.info('[macOS] App bundle copied successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error copying app bundle', e);
      rethrow;
    }
  }

  /// Set proper permissions on app bundle after copying
  Future<void> _setAppBundlePermissions(String appPath) async {
    LoggingService.info('[macOS] Setting app bundle permissions: $appPath');

    try {
      // Set directory permissions (755 - rwxr-xr-x)
      await Process.run('chmod', ['-R', '755', appPath]);

      // Find and set executable permissions for binaries in MacOS directory
      final macosDir = Directory(path.join(appPath, 'Contents', 'MacOS'));
      if (await macosDir.exists()) {
        await for (final entity in macosDir.list()) {
          if (entity is File) {
            // Make all files in MacOS directory executable
            await Process.run('chmod', ['+x', entity.path]);
            LoggingService.debug('[macOS] Set executable: ${entity.path}');
          }
        }
      }

      LoggingService.info('[macOS] App bundle permissions set successfully');
    } catch (e) {
      LoggingService.warning('[macOS] Error setting app bundle permissions', e);
      // Don't rethrow as this is not critical for basic functionality
    }
  }

  /// Check if there's enough disk space for installation
  Future<void> _checkDiskSpace(String sourcePath, String installDir) async {
    LoggingService.info('[macOS] Checking disk space for installation');

    try {
      // Get source size
      final sourceSize = await _getDirectorySize(sourcePath);
      LoggingService.info(
        '[macOS] Source app bundle size: ${_formatBytes(sourceSize)}',
      );

      // Get available space in installation directory
      final dfResult = await Process.run('df', ['-k', installDir]);
      if (dfResult.exitCode == 0) {
        final lines = dfResult.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            final availableKB = int.tryParse(parts[3]) ?? 0;
            final availableBytes = availableKB * 1024;

            LoggingService.info(
              '[macOS] Available disk space: ${_formatBytes(availableBytes)}',
            );

            // Require at least 2x the source size for safety
            final requiredSpace = sourceSize * 2;
            if (availableBytes < requiredSpace) {
              throw UpdateException(
                'Insufficient disk space. Required: ${_formatBytes(requiredSpace)}, Available: ${_formatBytes(availableBytes)}',
                installDir,
              );
            }
          }
        }
      }
    } catch (e) {
      if (e is UpdateException) {
        rethrow;
      }
      LoggingService.warning('[macOS] Could not check disk space', e);
      // Don't fail installation if we can't check disk space
    }
  }

  /// Get directory size recursively
  Future<int> _getDirectorySize(String dirPath) async {
    try {
      final duResult = await Process.run('du', ['-sk', dirPath]);
      if (duResult.exitCode == 0) {
        final output = duResult.stdout.toString().trim();
        final sizeKB = int.tryParse(output.split('\t')[0]) ?? 0;
        return sizeKB * 1024; // Convert to bytes
      }
    } catch (e) {
      LoggingService.warning('[macOS] Error getting directory size', e);
    }
    return 0;
  }

  /// Format bytes for human-readable display
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Remove existing installation if present
  Future<void> _removeExistingInstallation(String targetPath) async {
    LoggingService.info(
      '[macOS] Checking for existing installation: $targetPath',
    );

    try {
      final targetDir = Directory(targetPath);
      if (await targetDir.exists()) {
        LoggingService.info('[macOS] Removing existing installation');
        await targetDir.delete(recursive: true);

        // Wait a moment to ensure deletion is complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify deletion
        if (await targetDir.exists()) {
          throw UpdateException(
            'Failed to remove existing installation',
            targetPath,
          );
        }

        LoggingService.info(
          '[macOS] Existing installation removed successfully',
        );
      }
    } catch (e) {
      LoggingService.error('[macOS] Error removing existing installation', e);
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

      // Try to find Eden executable in various locations
      final possiblePaths = await _findEdenExecutables(installPath);

      if (possiblePaths.isEmpty) {
        LoggingService.warning(
          '[macOS] No Eden executables found in: $installPath',
        );
        return;
      }

      // Set permissions for all found executables
      for (final executablePath in possiblePaths) {
        if (await File(executablePath).exists()) {
          await fileHandler.makeExecutable(executablePath);
          LoggingService.info(
            '[macOS] Executable permissions set for: $executablePath',
          );
        }
      }
    } catch (e) {
      LoggingService.error('[macOS] Error setting executable permissions', e);
      // Don't rethrow as this is not critical for installation success
    }
  }

  /// Find all Eden executables in the installation directory
  Future<List<String>> _findEdenExecutables(String installPath) async {
    final executables = <String>[];
    final fileHandler = MacOSFileHandler();

    try {
      final installDir = Directory(installPath);
      if (!await installDir.exists()) {
        return executables;
      }

      await for (final entity in installDir.list(recursive: true)) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          if (fileHandler.isEdenExecutable(filename)) {
            executables.add(entity.path);
          }
        }
      }

      LoggingService.info(
        '[macOS] Found ${executables.length} Eden executables',
      );
      for (final exec in executables) {
        LoggingService.debug('[macOS] Found executable: $exec');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error finding Eden executables', e);
    }

    return executables;
  }

  /// Create portable mode directory structure
  Future<void> _createPortableModeDirectory(String installPath) async {
    LoggingService.info('[macOS] Creating portable mode directory');

    try {
      final userDir = Directory(path.join(installPath, 'user'));
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
        LoggingService.info('[macOS] Created portable mode user directory');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error creating portable mode directory', e);
      // Don't rethrow as this is not critical
    }
  }

  /// Validate installation structure
  Future<void> _validateInstallationStructure(String installPath) async {
    LoggingService.info('[macOS] Validating installation structure');

    try {
      final installDir = Directory(installPath);
      if (!await installDir.exists()) {
        throw UpdateException(
          'Installation directory does not exist',
          installPath,
        );
      }

      final fileHandler = MacOSFileHandler();
      final hasEdenFiles = await fileHandler.containsEdenFiles(installPath);

      if (!hasEdenFiles) {
        throw UpdateException(
          'No Eden files found in installation',
          installPath,
        );
      }

      LoggingService.info('[macOS] Installation structure validation passed');
    } catch (e) {
      LoggingService.error(
        '[macOS] Installation structure validation failed',
        e,
      );
      rethrow;
    }
  }

  /// Store installation metadata
  Future<void> _storeInstallationMetadata(
    String installPath,
    UpdateInfo updateInfo,
  ) async {
    LoggingService.info('[macOS] Storing installation metadata');

    try {
      // Store version information
      final channel = await _preferencesService.getReleaseChannel();
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);

      // Store installation date
      final now = DateTime.now().toIso8601String();
      await _preferencesService.setString('last_install_date', now);

      // Store installation path
      await _preferencesService.setString('install_path', installPath);

      LoggingService.info('[macOS] Installation metadata stored successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error storing installation metadata', e);
      // Don't rethrow as this is not critical
    }
  }

  /// Verify installation was successful
  Future<void> _verifyInstallation(
    String installPath,
    UpdateInfo updateInfo,
  ) async {
    LoggingService.info('[macOS] Verifying installation');

    try {
      final installDir = Directory(installPath);
      if (!await installDir.exists()) {
        throw UpdateException(
          'Installation directory missing after install',
          installPath,
        );
      }

      final fileHandler = MacOSFileHandler();
      final hasEdenFiles = await fileHandler.containsEdenFiles(installPath);

      if (!hasEdenFiles) {
        throw UpdateException('Eden files missing after install', installPath);
      }

      // Verify at least one executable exists and is executable
      final executables = await _findEdenExecutables(installPath);
      if (executables.isEmpty) {
        throw UpdateException(
          'No Eden executables found after install',
          installPath,
        );
      }

      // Check if at least one executable has proper permissions
      bool hasExecutablePermissions = false;
      for (final execPath in executables) {
        if (await fileHandler.validateExecutablePermissions(execPath)) {
          hasExecutablePermissions = true;
          break;
        }
      }

      if (!hasExecutablePermissions) {
        LoggingService.warning(
          '[macOS] No executables have proper permissions, but installation may still work',
        );
      }

      LoggingService.info('[macOS] Installation verification passed');
    } catch (e) {
      LoggingService.error('[macOS] Installation verification failed', e);
      rethrow;
    }
  }

  /// Validate DMG file before mounting
  Future<bool> _validateDMGFile(String dmgPath) async {
    LoggingService.info('[macOS] Validating DMG file: $dmgPath');

    try {
      final dmgFile = File(dmgPath);
      if (!await dmgFile.exists()) {
        LoggingService.error('[macOS] DMG file does not exist');
        return false;
      }

      // Check file size (should be reasonable for Eden)
      final stat = await dmgFile.stat();
      if (stat.size < 1024) {
        // Less than 1KB is suspicious
        LoggingService.error('[macOS] DMG file too small: ${stat.size} bytes');
        return false;
      }

      // Use file command to verify it's actually a DMG
      final fileResult = await Process.run('file', [dmgPath]);
      if (fileResult.exitCode == 0) {
        final fileType = fileResult.stdout.toString().toLowerCase();
        if (!fileType.contains('disk image') && !fileType.contains('dmg')) {
          LoggingService.warning(
            '[macOS] File may not be a valid DMG: $fileType',
          );
          // Don't return false here as file command might not recognize all DMG variants
        }
      }

      // Try to verify with hdiutil (this is more reliable but slower)
      try {
        final verifyResult = await Process.run('hdiutil', ['verify', dmgPath]);
        if (verifyResult.exitCode != 0) {
          LoggingService.warning(
            '[macOS] DMG verification failed: ${verifyResult.stderr}',
          );
          // Don't return false as some valid DMGs might fail verification
        } else {
          LoggingService.info('[macOS] DMG verification passed');
        }
      } catch (e) {
        LoggingService.warning('[macOS] Could not verify DMG with hdiutil', e);
      }

      LoggingService.info('[macOS] DMG file validation passed');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error validating DMG file', e);
      return false;
    }
  }

  /// Validate app bundle structure
  Future<bool> _validateAppBundle(String appPath) async {
    LoggingService.info('[macOS] Validating app bundle: $appPath');

    try {
      final appDir = Directory(appPath);
      if (!await appDir.exists()) {
        LoggingService.error('[macOS] App bundle does not exist');
        return false;
      }

      if (!appPath.endsWith('.app')) {
        LoggingService.error('[macOS] Path does not end with .app');
        return false;
      }

      // Check for required .app bundle structure
      final contentsDir = Directory(path.join(appPath, 'Contents'));
      if (!await contentsDir.exists()) {
        LoggingService.error('[macOS] Contents directory missing');
        return false;
      }

      final macosDir = Directory(path.join(appPath, 'Contents', 'MacOS'));
      if (!await macosDir.exists()) {
        LoggingService.error('[macOS] MacOS directory missing');
        return false;
      }

      final infoPlist = File(path.join(appPath, 'Contents', 'Info.plist'));
      if (!await infoPlist.exists()) {
        LoggingService.warning('[macOS] Info.plist missing (not critical)');
      }

      // Check if there's at least one executable in MacOS directory
      bool hasExecutable = false;
      await for (final entity in macosDir.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          final fileHandler = MacOSFileHandler();
          if (fileHandler.isEdenExecutable(filename)) {
            hasExecutable = true;
            LoggingService.info('[macOS] Found executable: $filename');
            break;
          }
        }
      }

      if (!hasExecutable) {
        LoggingService.error('[macOS] No Eden executable found in app bundle');
        return false;
      }

      LoggingService.info('[macOS] App bundle validation passed');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error validating app bundle', e);
      return false;
    }
  }

  /// Validate archive file before extraction
  Future<bool> _validateArchiveFile(String archivePath) async {
    LoggingService.info('[macOS] Validating archive file: $archivePath');

    try {
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        LoggingService.error('[macOS] Archive file does not exist');
        return false;
      }

      // Check file size
      final stat = await archiveFile.stat();
      if (stat.size < 1024) {
        // Less than 1KB is suspicious
        LoggingService.error(
          '[macOS] Archive file too small: ${stat.size} bytes',
        );
        return false;
      }

      // Check file extension
      final extension = path.extension(archivePath).toLowerCase();
      final supportedExtensions = ['.zip', '.tar', '.gz', '.bz2', '.xz'];
      final fileName = path.basename(archivePath).toLowerCase();

      bool isSupported =
          supportedExtensions.any((ext) => extension.endsWith(ext)) ||
          fileName.endsWith('.tar.gz') ||
          fileName.endsWith('.tar.bz2') ||
          fileName.endsWith('.tar.xz');

      if (!isSupported) {
        LoggingService.error('[macOS] Unsupported archive format: $extension');
        return false;
      }

      // Use file command to verify archive type
      try {
        final fileResult = await Process.run('file', [archivePath]);
        if (fileResult.exitCode == 0) {
          final fileType = fileResult.stdout.toString().toLowerCase();
          LoggingService.debug('[macOS] Archive file type: $fileType');

          // Basic validation - should contain archive-related keywords
          if (!fileType.contains('archive') &&
              !fileType.contains('zip') &&
              !fileType.contains('tar') &&
              !fileType.contains('gzip') &&
              !fileType.contains('bzip') &&
              !fileType.contains('compressed')) {
            LoggingService.warning(
              '[macOS] File may not be a valid archive: $fileType',
            );
          }
        }
      } catch (e) {
        LoggingService.warning('[macOS] Could not verify archive type', e);
      }

      LoggingService.info('[macOS] Archive file validation passed');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error validating archive file', e);
      return false;
    }
  }

  /// Check disk space for archive extraction
  Future<void> _checkArchiveDiskSpace(
    String archivePath,
    String installDir,
  ) async {
    LoggingService.info('[macOS] Checking disk space for archive extraction');

    try {
      // Estimate extracted size (assume 3x compressed size as safety margin)
      final archiveFile = File(archivePath);
      final archiveSize = (await archiveFile.stat()).size;
      final estimatedExtractedSize = archiveSize * 3;

      LoggingService.info('[macOS] Archive size: ${_formatBytes(archiveSize)}');
      LoggingService.info(
        '[macOS] Estimated extracted size: ${_formatBytes(estimatedExtractedSize)}',
      );

      // Get available space
      final dfResult = await Process.run('df', ['-k', installDir]);
      if (dfResult.exitCode == 0) {
        final lines = dfResult.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            final availableKB = int.tryParse(parts[3]) ?? 0;
            final availableBytes = availableKB * 1024;

            LoggingService.info(
              '[macOS] Available disk space: ${_formatBytes(availableBytes)}',
            );

            if (availableBytes < estimatedExtractedSize) {
              throw UpdateException(
                'Insufficient disk space. Estimated need: ${_formatBytes(estimatedExtractedSize)}, Available: ${_formatBytes(availableBytes)}',
                installDir,
              );
            }
          }
        }
      }
    } catch (e) {
      if (e is UpdateException) {
        rethrow;
      }
      LoggingService.warning(
        '[macOS] Could not check disk space for archive',
        e,
      );
    }
  }

  /// Clean installation directory before extraction
  Future<void> _cleanInstallationDirectory(String installDir) async {
    LoggingService.info('[macOS] Cleaning installation directory: $installDir');

    try {
      final dir = Directory(installDir);
      if (await dir.exists()) {
        // Remove all contents but keep the directory
        await for (final entity in dir.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
        LoggingService.info('[macOS] Installation directory cleaned');
      } else {
        // Create the directory if it doesn't exist
        await dir.create(recursive: true);
        LoggingService.info('[macOS] Installation directory created');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error cleaning installation directory', e);
      rethrow;
    }
  }

  /// Verify archive extraction was successful
  Future<void> _verifyArchiveExtraction(String installDir) async {
    LoggingService.info('[macOS] Verifying archive extraction');

    try {
      final dir = Directory(installDir);
      if (!await dir.exists()) {
        throw UpdateException(
          'Installation directory does not exist after extraction',
          installDir,
        );
      }

      // Check if directory has any contents
      final contents = await dir.list().toList();
      if (contents.isEmpty) {
        throw UpdateException('No files extracted from archive', installDir);
      }

      // Use file handler to check for Eden files
      final fileHandler = MacOSFileHandler();
      final hasEdenFiles = await fileHandler.containsEdenFiles(installDir);

      if (!hasEdenFiles) {
        LoggingService.warning(
          '[macOS] No Eden files detected after extraction, but continuing',
        );
        // Don't throw here as the archive might contain Eden files we don't recognize
      }

      LoggingService.info('[macOS] Archive extraction verification passed');
    } catch (e) {
      LoggingService.error('[macOS] Archive extraction verification failed', e);
      rethrow;
    }
  }

  /// Set proper permissions for extracted files
  Future<void> _setArchivePermissions(String installDir) async {
    LoggingService.info('[macOS] Setting permissions for extracted files');

    try {
      final fileHandler = MacOSFileHandler();
      final dir = Directory(installDir);

      if (!await dir.exists()) {
        LoggingService.warning(
          '[macOS] Install directory does not exist for permission setting',
        );
        return;
      }

      int fileCount = 0;
      int executableCount = 0;

      // Recursively process all files
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          final filename = path.basename(entity.path);

          // Set executable permissions for Eden executables
          if (fileHandler.isEdenExecutable(filename)) {
            try {
              await fileHandler.makeExecutable(entity.path);
              executableCount++;
              LoggingService.debug('[macOS] Set executable: ${entity.path}');
            } catch (e) {
              LoggingService.warning(
                '[macOS] Failed to set executable: ${entity.path}',
                e,
              );
            }
          }

          // Set readable permissions for all files
          try {
            await Process.run('chmod', ['644', entity.path]);
          } catch (e) {
            LoggingService.warning(
              '[macOS] Failed to set readable permissions: ${entity.path}',
              e,
            );
          }
        } else if (entity is Directory) {
          // Set directory permissions (755 - rwxr-xr-x)
          try {
            await Process.run('chmod', ['755', entity.path]);
          } catch (e) {
            LoggingService.warning(
              '[macOS] Failed to set directory permissions: ${entity.path}',
              e,
            );
          }
        }
      }

      LoggingService.info(
        '[macOS] Processed $fileCount files, set $executableCount as executable',
      );
    } catch (e) {
      LoggingService.error('[macOS] Error setting archive permissions', e);
      // Don't rethrow as this is not critical for basic functionality
    }
  }

  /// Clean up failed installation
  Future<void> _cleanupFailedInstallation(String installPath) async {
    LoggingService.info('[macOS] Cleaning up failed installation');

    try {
      final installDir = Directory(installPath);
      if (await installDir.exists()) {
        // Only clean up if the directory looks like it was created by us
        final contents = await installDir.list().toList();
        if (contents.isNotEmpty) {
          LoggingService.info('[macOS] Removing failed installation directory');
          await installDir.delete(recursive: true);
        }
      }
    } catch (e) {
      LoggingService.warning('[macOS] Error during cleanup', e);
      // Don't rethrow cleanup errors
    }
  }
}
