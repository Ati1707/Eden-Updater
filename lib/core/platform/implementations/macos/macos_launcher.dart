import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_launcher.dart';
import '../../../services/logging_service.dart';
import '../../../errors/app_exceptions.dart';
import '../../../../services/storage/preferences_service.dart';
import 'macos_file_handler.dart';

/// macOS-specific launcher implementation
class MacOSLauncher implements IPlatformLauncher {
  final PreferencesService _preferencesService;

  MacOSLauncher(this._preferencesService);

  @override
  Future<void> launchEden() async {
    LoggingService.info('[macOS] Launching Eden');

    try {
      final channel = await _preferencesService.getReleaseChannel();
      final installDir = await _getInstallationDirectory(channel);
      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installDir, channel);

      LoggingService.info('[macOS] Eden executable path: $edenPath');

      // Check if Eden executable exists
      if (!await File(edenPath).exists()) {
        LoggingService.error('[macOS] Eden executable not found: $edenPath');
        throw LauncherException('Eden executable not found', edenPath);
      }

      // Check if it's an .app bundle
      if (edenPath.contains('.app')) {
        await _launchAppBundle(edenPath);
      } else {
        await _launchExecutable(edenPath);
      }

      LoggingService.info('[macOS] Eden launched successfully');
    } catch (e) {
      LoggingService.error('[macOS] Failed to launch Eden', e);
      rethrow;
    }
  }

  @override
  Future<void> createDesktopShortcut() async {
    LoggingService.info('[macOS] Creating desktop shortcut');

    try {
      final channel = await _preferencesService.getReleaseChannel();
      final installDir = await _getInstallationDirectory(channel);

      // Create desktop shortcut
      await _createDesktopShortcut(installDir, channel);

      // Create Applications folder shortcut
      await _createApplicationsShortcut(installDir, channel);

      LoggingService.info('[macOS] Shortcuts created successfully');
    } catch (e) {
      LoggingService.error('[macOS] Failed to create shortcuts', e);
      rethrow;
    }
  }

  @override
  Future<String?> findEdenExecutable(String installPath, String channel) async {
    LoggingService.debug('[macOS] Finding Eden executable in: $installPath');

    try {
      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installPath, channel);

      if (await File(edenPath).exists()) {
        LoggingService.debug('[macOS] Found Eden executable: $edenPath');
        return edenPath;
      }

      LoggingService.debug('[macOS] Eden executable not found at: $edenPath');
      return null;
    } catch (e) {
      LoggingService.error('[macOS] Error finding Eden executable', e);
      return null;
    }
  }

  /// Get installation directory for channel
  Future<String> _getInstallationDirectory(String channel) async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      throw LauncherException('HOME environment variable not found', '');
    }

    final baseDir = path.join(homeDir, 'Documents', 'Eden');
    final channelDir = channel == 'nightly' ? 'Eden-Nightly' : 'Eden-Release';
    return path.join(baseDir, channelDir);
  }

  /// Check if Eden is currently running
  Future<bool> isEdenRunning(String channel) async {
    LoggingService.debug(
      '[macOS] Checking if Eden is running for channel: $channel',
    );

    try {
      // Use pgrep to check for running Eden processes
      final result = await Process.run('pgrep', ['-f', 'Eden']);

      final isRunning = result.exitCode == 0;

      if (isRunning && result.stdout.toString().trim().isNotEmpty) {
        final pids = result.stdout.toString().trim().split('\n');
        LoggingService.debug(
          '[macOS] Found ${pids.length} Eden process(es): ${pids.join(', ')}',
        );
      }

      LoggingService.debug('[macOS] Eden running status: $isRunning');
      return isRunning;
    } catch (e) {
      LoggingService.error('[macOS] Error checking if Eden is running', e);
      return false;
    }
  }

  /// Terminate all running Eden processes
  Future<void> terminateEden(String channel) async {
    LoggingService.info('[macOS] Terminating Eden for channel: $channel');

    try {
      // First check if Eden is running
      final isRunning = await isEdenRunning(channel);
      if (!isRunning) {
        LoggingService.info('[macOS] No Eden processes found to terminate');
        return;
      }

      // Use pkill to terminate Eden processes gracefully (SIGTERM)
      final result = await Process.run('pkill', ['-f', 'Eden']);

      if (result.exitCode == 0) {
        LoggingService.info(
          '[macOS] Sent termination signal to Eden processes',
        );

        // Wait for processes to clean up gracefully
        await Future.delayed(const Duration(seconds: 3));

        // Verify processes have terminated
        final stillRunning = await isEdenRunning(channel);
        if (stillRunning) {
          LoggingService.warning(
            '[macOS] Eden processes still running, forcing termination',
          );

          // Force kill if processes are still running (SIGKILL)
          final forceResult = await Process.run('pkill', ['-9', '-f', 'Eden']);
          if (forceResult.exitCode == 0) {
            LoggingService.info('[macOS] Forcefully terminated Eden processes');
            await Future.delayed(const Duration(seconds: 1));
          }
        } else {
          LoggingService.info('[macOS] Eden processes terminated successfully');
        }
      } else {
        LoggingService.warning(
          '[macOS] pkill returned non-zero exit code: ${result.exitCode}',
        );
        if (result.stderr.toString().trim().isNotEmpty) {
          LoggingService.warning('[macOS] pkill stderr: ${result.stderr}');
        }
      }
    } catch (e) {
      LoggingService.error('[macOS] Error terminating Eden', e);
      throw LauncherException(
        'Failed to terminate Eden processes: ${e.toString()}',
        channel,
      );
    }
  }

  /// Launch an .app bundle
  Future<bool> _launchAppBundle(String appPath) async {
    LoggingService.info('[macOS] Launching .app bundle: $appPath');

    try {
      await Process.start('open', [appPath]);
      LoggingService.info('[macOS] .app bundle launched successfully');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error launching .app bundle', e);
      throw LauncherException(
        'Failed to launch .app bundle: ${e.toString()}',
        appPath,
      );
    }
  }

  /// Launch a regular executable
  Future<bool> _launchExecutable(String executablePath) async {
    LoggingService.info('[macOS] Launching executable: $executablePath');

    try {
      await Process.start(executablePath, []);
      LoggingService.info('[macOS] Executable launched successfully');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error launching executable', e);
      throw LauncherException(
        'Failed to launch executable: ${e.toString()}',
        executablePath,
      );
    }
  }

  /// Create desktop shortcut
  Future<void> _createDesktopShortcut(
    String installPath,
    String channel,
  ) async {
    LoggingService.info(
      '[macOS] Creating desktop shortcut for channel: $channel',
    );

    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) {
        LoggingService.warning('[macOS] HOME environment variable not found');
        throw LauncherException('HOME environment variable not found', '');
      }

      final desktopDir = path.join(homeDir, 'Desktop');

      // Ensure desktop directory exists
      final desktopDirectory = Directory(desktopDir);
      if (!await desktopDirectory.exists()) {
        LoggingService.warning(
          '[macOS] Desktop directory does not exist: $desktopDir',
        );
        return;
      }

      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installPath, channel);

      final shortcutName = channel == 'nightly' ? 'Eden Nightly' : 'Eden';
      final shortcutPath = path.join(desktopDir, '$shortcutName.command');

      // Create shell script that launches Eden
      final scriptContent = _createLaunchScript(edenPath);

      await File(shortcutPath).writeAsString(scriptContent);
      await fileHandler.makeExecutable(shortcutPath);

      LoggingService.info('[macOS] Desktop shortcut created: $shortcutPath');
    } catch (e) {
      LoggingService.error('[macOS] Error creating desktop shortcut', e);
      // Don't rethrow as shortcuts are not critical for core functionality
    }
  }

  /// Create Applications folder shortcut (symlink)
  Future<void> _createApplicationsShortcut(
    String installPath,
    String channel,
  ) async {
    LoggingService.info(
      '[macOS] Creating Applications folder shortcut for channel: $channel',
    );

    try {
      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installPath, channel);

      // Only create symlink if it's an .app bundle
      if (!edenPath.contains('.app')) {
        LoggingService.info(
          '[macOS] Skipping Applications shortcut for non-.app bundle: $edenPath',
        );
        return;
      }

      final appBundlePath = edenPath.substring(0, edenPath.indexOf('.app') + 4);
      final shortcutName = channel == 'nightly'
          ? 'Eden Nightly.app'
          : 'Eden.app';
      final applicationsPath = path.join('/Applications', shortcutName);

      // Verify the source .app bundle exists
      if (!await Directory(appBundlePath).exists()) {
        LoggingService.warning(
          '[macOS] Source .app bundle does not exist: $appBundlePath',
        );
        return;
      }

      // Remove existing symlink if it exists
      final existingLink = Link(applicationsPath);
      if (await existingLink.exists()) {
        await existingLink.delete();
        LoggingService.debug('[macOS] Removed existing Applications shortcut');
      }

      // Create new symlink
      await Link(applicationsPath).create(appBundlePath);

      LoggingService.info(
        '[macOS] Applications shortcut created: $applicationsPath -> $appBundlePath',
      );
    } catch (e) {
      LoggingService.error('[macOS] Error creating Applications shortcut', e);
      // Don't rethrow as shortcuts are not critical for core functionality
    }
  }

  /// Create launch script content
  String _createLaunchScript(String edenPath) {
    final script = StringBuffer();
    script.writeln('#!/bin/bash');
    script.writeln('# Eden Launcher Script');
    script.writeln('# Generated by Eden Updater');
    script.writeln();

    if (edenPath.contains('.app')) {
      script.writeln('open "$edenPath" &');
    } else {
      script.writeln('"$edenPath" &');
    }

    script.writeln();
    script.writeln('exit 0');

    return script.toString();
  }
}
