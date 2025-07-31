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
        await _launchAppBundle(edenPath, false);
      } else {
        await _launchExecutable(edenPath, false);
      }
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
      await _createDesktopShortcut(installDir, channel, false);

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

  Future<bool> isEdenRunning(String channel) async {
    LoggingService.debug(
      '[macOS] Checking if Eden is running for channel: $channel',
    );

    try {
      // Use pgrep to check for running Eden processes
      final result = await Process.run('pgrep', ['-f', 'Eden']);

      final isRunning = result.exitCode == 0;
      LoggingService.debug('[macOS] Eden running status: $isRunning');

      return isRunning;
    } catch (e) {
      LoggingService.error('[macOS] Error checking if Eden is running', e);
      return false;
    }
  }

  Future<void> terminateEden(String channel) async {
    LoggingService.info('[macOS] Terminating Eden for channel: $channel');

    try {
      // Use pkill to terminate Eden processes
      final result = await Process.run('pkill', ['-f', 'Eden']);

      if (result.exitCode == 0) {
        LoggingService.info('[macOS] Eden terminated successfully');

        // Wait a moment for processes to clean up
        await Future.delayed(const Duration(seconds: 2));
      } else {
        LoggingService.info('[macOS] No Eden processes found to terminate');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error terminating Eden', e);
      rethrow;
    }
  }

  /// Launch an .app bundle
  Future<bool> _launchAppBundle(String appPath, bool portableMode) async {
    LoggingService.info('[macOS] Launching .app bundle: $appPath');

    try {
      final args = ['open', appPath];

      // Add portable mode arguments if needed
      if (portableMode) {
        args.addAll(['--args', '--portable']);
      }

      await Process.start('open', [appPath]);

      // Don't wait for the process to complete as it will run independently
      LoggingService.info('[macOS] .app bundle launched successfully');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error launching .app bundle', e);
      return false;
    }
  }

  /// Launch a regular executable
  Future<bool> _launchExecutable(
    String executablePath,
    bool portableMode,
  ) async {
    LoggingService.info('[macOS] Launching executable: $executablePath');

    try {
      final args = <String>[];

      // Add portable mode arguments if needed
      if (portableMode) {
        args.add('--portable');
      }

      await Process.start(executablePath, args);

      // Don't wait for the process to complete as it will run independently
      LoggingService.info('[macOS] Executable launched successfully');
      return true;
    } catch (e) {
      LoggingService.error('[macOS] Error launching executable', e);
      return false;
    }
  }

  /// Create desktop shortcut
  Future<void> _createDesktopShortcut(
    String installPath,
    String channel,
    bool portableMode,
  ) async {
    LoggingService.info('[macOS] Creating desktop shortcut');

    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) {
        LoggingService.warning('[macOS] HOME environment variable not found');
        return;
      }

      final desktopDir = path.join(homeDir, 'Desktop');
      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installPath, channel);

      final shortcutName = channel == 'nightly' ? 'Eden Nightly' : 'Eden';
      final shortcutPath = path.join(desktopDir, '$shortcutName.command');

      // Create shell script that launches Eden
      final scriptContent = _createLaunchScript(edenPath, portableMode);

      await File(shortcutPath).writeAsString(scriptContent);
      await fileHandler.makeExecutable(shortcutPath);

      LoggingService.info('[macOS] Desktop shortcut created: $shortcutPath');
    } catch (e) {
      LoggingService.error('[macOS] Error creating desktop shortcut', e);
      // Don't rethrow as shortcuts are not critical
    }
  }

  /// Create Applications folder shortcut (symlink)
  Future<void> _createApplicationsShortcut(
    String installPath,
    String channel,
  ) async {
    LoggingService.info('[macOS] Creating Applications folder shortcut');

    try {
      final fileHandler = MacOSFileHandler();
      final edenPath = fileHandler.getEdenExecutablePath(installPath, channel);

      // Only create symlink if it's an .app bundle
      if (!edenPath.contains('.app')) {
        LoggingService.info(
          '[macOS] Skipping Applications shortcut for non-.app bundle',
        );
        return;
      }

      final appBundlePath = edenPath.substring(0, edenPath.indexOf('.app') + 4);
      final shortcutName = channel == 'nightly'
          ? 'Eden Nightly.app'
          : 'Eden.app';
      final applicationsPath = path.join('/Applications', shortcutName);

      // Remove existing symlink if it exists
      final existingLink = Link(applicationsPath);
      if (await existingLink.exists()) {
        await existingLink.delete();
      }

      // Create new symlink
      await Link(applicationsPath).create(appBundlePath);

      LoggingService.info(
        '[macOS] Applications shortcut created: $applicationsPath',
      );
    } catch (e) {
      LoggingService.error('[macOS] Error creating Applications shortcut', e);
      // Don't rethrow as shortcuts are not critical
    }
  }

  /// Create launch script content
  String _createLaunchScript(String edenPath, bool portableMode) {
    final buffer = StringBuffer();
    buffer.writeln('#!/bin/bash');
    buffer.writeln('# Eden Launcher Script');
    buffer.writeln('');

    if (edenPath.contains('.app')) {
      buffer.write('open "$edenPath"');
      if (portableMode) {
        buffer.write(' --args --portable');
      }
    } else {
      buffer.write('"$edenPath"');
      if (portableMode) {
        buffer.write(' --portable');
      }
    }

    buffer.writeln(' &');
    buffer.writeln('exit 0');

    return buffer.toString();
  }
}
