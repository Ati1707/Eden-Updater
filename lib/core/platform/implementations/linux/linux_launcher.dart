import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_launcher.dart';
import '../../../errors/app_exceptions.dart';
import '../../../services/logging_service.dart';

import '../../../../services/storage/preferences_service.dart';
import '../../../../services/installation/installation_service.dart';
import 'linux_file_handler.dart';

/// Linux-specific launcher implementation
class LinuxLauncher implements IPlatformLauncher {
  final PreferencesService _preferencesService;
  final InstallationService _installationService;

  LinuxLauncher(this._preferencesService, this._installationService);

  @override
  Future<void> launchEden() async {
    LoggingService.info('Launching Eden on Linux');

    try {
      final channel = await _preferencesService.getReleaseChannel();
      String? edenExecutable = await _preferencesService.getEdenExecutablePath(
        channel,
      );

      // If no stored executable path, try to find it
      if (edenExecutable == null || !await File(edenExecutable).exists()) {
        final installPath = await _installationService.getInstallPath();
        edenExecutable = await findEdenExecutable(installPath, channel);
      }

      // Verify executable exists
      if (edenExecutable == null || !await File(edenExecutable).exists()) {
        LoggingService.error('Eden executable not found');
        throw LauncherException(
          'Eden is not installed',
          'Please download Eden first before launching',
        );
      }

      LoggingService.info('Launching Eden executable: $edenExecutable');

      // Ensure the executable has proper permissions before launching
      await _ensureExecutablePermissions(edenExecutable);

      // Launch Eden as a detached process
      await Process.start(edenExecutable, [], mode: ProcessStartMode.detached);

      LoggingService.info('Eden launched successfully');
    } catch (e) {
      LoggingService.error('Failed to launch Eden on Linux', e);
      if (e is LauncherException) {
        rethrow;
      }
      throw LauncherException(
        'Failed to launch Eden',
        'Error starting Eden: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> createDesktopShortcut() async {
    LoggingService.info('Creating Linux desktop shortcut');

    try {
      final channel = await _preferencesService.getReleaseChannel();
      final edenExecutable = await _preferencesService.getEdenExecutablePath(
        channel,
      );

      if (edenExecutable == null || !await File(edenExecutable).exists()) {
        throw LauncherException(
          'Eden executable not found',
          'Cannot create shortcut: Eden is not installed',
        );
      }

      final desktopPaths = await _getDesktopPaths();
      if (desktopPaths.isEmpty) {
        LoggingService.warning('No desktop paths found for shortcut creation');
        return;
      }

      final shortcutContent = _generateDesktopEntry(edenExecutable, channel);
      final shortcutName = channel == 'nightly'
          ? 'Eden-Nightly.desktop'
          : 'Eden.desktop';

      bool shortcutCreated = false;
      for (final desktopPath in desktopPaths) {
        try {
          final desktopDir = Directory(desktopPath);
          if (!await desktopDir.exists()) {
            await desktopDir.create(recursive: true);
          }

          final shortcutFile = File(path.join(desktopPath, shortcutName));
          await shortcutFile.writeAsString(shortcutContent);

          // Make the desktop file executable
          await Process.run('chmod', ['+x', shortcutFile.path]);

          LoggingService.info(
            'Desktop shortcut created at: ${shortcutFile.path}',
          );
          shortcutCreated = true;

          // Only create in the first successful location
          break;
        } catch (e) {
          LoggingService.warning(
            'Failed to create shortcut at $desktopPath',
            e,
          );
          // Continue to next path if this one fails
          continue;
        }
      }

      if (!shortcutCreated) {
        throw LauncherException(
          'Failed to create desktop shortcut',
          'Could not write to any desktop location',
        );
      }

      LoggingService.info('Linux desktop shortcut created successfully');
    } catch (e) {
      LoggingService.error('Failed to create Linux desktop shortcut', e);
      if (e is LauncherException) {
        rethrow;
      }
      throw LauncherException('Error creating Linux shortcut', e.toString());
    }
  }

  @override
  Future<String?> findEdenExecutable(String installPath, String channel) async {
    LoggingService.info('Finding Eden executable in Linux installation');
    LoggingService.info('Install path: $installPath');
    LoggingService.info('Channel: $channel');

    try {
      // First, try the expected path
      final fileHandler = LinuxFileHandler();
      final expectedPath = fileHandler.getEdenExecutablePath(
        installPath,
        channel,
      );
      LoggingService.info('Checking expected path: $expectedPath');

      if (await File(expectedPath).exists()) {
        LoggingService.info('Found Eden executable at expected path');
        // Store the path for future use
        await _preferencesService.setEdenExecutablePath(channel, expectedPath);
        return expectedPath;
      }

      // If not found at expected path, search the installation directory
      LoggingService.info(
        'Searching installation directory for Eden executable',
      );
      final installDir = Directory(installPath);

      if (!await installDir.exists()) {
        LoggingService.warning(
          'Installation directory does not exist: $installPath',
        );
        return null;
      }

      await for (final entity in installDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final fileHandler = LinuxFileHandler();
          if (fileHandler.isEdenExecutable(fileName)) {
            LoggingService.info('Found Eden executable: ${entity.path}');
            // Store the path for future use
            await _preferencesService.setEdenExecutablePath(
              channel,
              entity.path,
            );
            return entity.path;
          }
        }
      }

      LoggingService.warning(
        'Eden executable not found in installation directory',
      );
      return null;
    } catch (e) {
      LoggingService.error('Error finding Eden executable on Linux', e);
      return null;
    }
  }

  /// Generate .desktop file content for Linux desktop shortcut
  String _generateDesktopEntry(String executablePath, String channel) {
    final name = channel == 'nightly' ? 'Eden Nightly' : 'Eden';
    final comment = channel == 'nightly'
        ? 'Nintendo Switch Emulator (Nightly Build)'
        : 'Nintendo Switch Emulator';

    // Get the updater executable path (current executable) for smart shortcuts
    final updaterExecutable = Platform.resolvedExecutable;

    // Enhanced desktop entry with better integration
    return '''[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$updaterExecutable --auto-launch --channel $channel
Icon=applications-games
Terminal=false
Categories=Game;Emulator;
StartupNotify=true
MimeType=application/x-nintendo-switch-rom;
Keywords=nintendo;switch;emulator;gaming;eden;
StartupWMClass=Eden
''';
  }

  /// Get possible desktop paths for shortcut creation
  Future<List<String>> _getDesktopPaths() async {
    final paths = <String>[];

    try {
      // Get user's home directory
      final homeDir = Platform.environment['HOME'] ?? '';
      if (homeDir.isNotEmpty) {
        // User desktop directory
        paths.add(path.join(homeDir, 'Desktop'));

        // User applications directory (for app launchers)
        paths.add(path.join(homeDir, '.local', 'share', 'applications'));
      }

      // Try to get XDG desktop directory
      try {
        final result = await Process.run('xdg-user-dir', ['DESKTOP']);
        if (result.exitCode == 0) {
          final xdgDesktop = result.stdout.toString().trim();
          if (xdgDesktop.isNotEmpty && xdgDesktop != 'DESKTOP') {
            paths.add(xdgDesktop);
          }
        }
      } catch (e) {
        LoggingService.info('xdg-user-dir not available, using default paths');
      }

      // Add system-wide paths (requires elevated permissions, so lower priority)
      paths.addAll([
        '/usr/share/applications',
        '/usr/local/share/applications',
      ]);

      // Filter out paths that don't exist or aren't writable
      final validPaths = <String>[];
      for (final path in paths) {
        try {
          final dir = Directory(path);
          if (await dir.exists()) {
            // Test if we can write to this directory
            final testFile = File('$path/.eden_test');
            try {
              await testFile.writeAsString('test');
              await testFile.delete();
              validPaths.add(path);
            } catch (e) {
              LoggingService.info('Cannot write to directory: $path');
            }
          }
        } catch (e) {
          LoggingService.info('Error checking directory: $path');
        }
      }

      LoggingService.info('Valid desktop paths found: $validPaths');
      return validPaths;
    } catch (e) {
      LoggingService.error('Error getting desktop paths', e);
      return [];
    }
  }

  /// Ensure the executable has proper permissions
  Future<void> _ensureExecutablePermissions(String executablePath) async {
    try {
      LoggingService.info(
        'Ensuring executable permissions for: $executablePath',
      );

      // Check if file is already executable
      final statResult = await Process.run('stat', [
        '-c',
        '%a',
        executablePath,
      ]);
      if (statResult.exitCode == 0) {
        final permissions = statResult.stdout.toString().trim();
        LoggingService.info('Current permissions: $permissions');

        // If permissions don't include execute bit, add it
        if (!permissions.contains('7') &&
            !permissions.contains('5') &&
            !permissions.contains('1')) {
          final chmodResult = await Process.run('chmod', [
            '+x',
            executablePath,
          ]);
          if (chmodResult.exitCode != 0) {
            LoggingService.warning(
              'Failed to set executable permissions: ${chmodResult.stderr}',
            );
          } else {
            LoggingService.info(
              'Added executable permissions to: $executablePath',
            );
          }
        }
      }
    } catch (e) {
      LoggingService.warning(
        'Error checking/setting executable permissions',
        e,
      );
      // Don't throw as this is not critical for launching
    }
  }
}
