import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_launcher.dart';
import '../../../errors/app_exceptions.dart';
import '../../../services/logging_service.dart';

import '../../../../services/storage/preferences_service.dart';
import '../../../../services/installation/installation_service.dart';
import 'windows_file_handler.dart';

/// Windows-specific launcher implementation
class WindowsLauncher implements IPlatformLauncher {
  final PreferencesService _preferencesService;
  final InstallationService _installationService;

  WindowsLauncher(this._preferencesService, this._installationService);

  @override
  Future<void> launchEden() async {
    LoggingService.info('Launching Eden on Windows');

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

      // Launch Eden as a detached process
      await Process.start(edenExecutable, [], mode: ProcessStartMode.detached);

      LoggingService.info('Eden launched successfully');
    } catch (e) {
      LoggingService.error('Failed to launch Eden on Windows', e);
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
    LoggingService.info('Creating Windows desktop shortcut');

    try {
      final channel = await _preferencesService.getReleaseChannel();
      final channelName = channel == 'nightly' ? 'Nightly' : 'Stable';
      final shortcutName = 'Eden $channelName.lnk';

      // Get the updater executable path (current executable)
      final updaterExecutable = Platform.resolvedExecutable;
      if (!await File(updaterExecutable).exists()) {
        throw LauncherException(
          'Updater executable not found',
          'Cannot create shortcut without valid executable',
        );
      }

      LoggingService.info('Updater executable: $updaterExecutable');

      // Get desktop path using PowerShell
      final desktopResult = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetFolderPath("Desktop")',
      ]);

      if (desktopResult.exitCode != 0) {
        throw LauncherException(
          'Failed to get desktop path',
          desktopResult.stderr.toString(),
        );
      }

      final desktopPath = desktopResult.stdout.toString().trim();
      final shortcutPath = path.join(desktopPath, shortcutName);

      LoggingService.info('Creating shortcut at: $shortcutPath');

      // Create PowerShell script to create shortcut with auto-launch and channel arguments
      final powershellScript =
          '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("$shortcutPath")
\$Shortcut.TargetPath = "$updaterExecutable"
\$Shortcut.Arguments = "--auto-launch --channel $channel"
\$Shortcut.WorkingDirectory = "${path.dirname(updaterExecutable)}"
\$Shortcut.IconLocation = "$updaterExecutable"
\$Shortcut.Description = "Eden $channelName Emulator"
\$Shortcut.Save()
''';

      final scriptResult = await Process.run('powershell', [
        '-Command',
        powershellScript,
      ]);

      if (scriptResult.exitCode != 0) {
        throw LauncherException(
          'Failed to create shortcut',
          scriptResult.stderr.toString(),
        );
      }

      LoggingService.info('Windows desktop shortcut created successfully');
    } catch (e) {
      LoggingService.error('Failed to create Windows desktop shortcut', e);
      if (e is LauncherException) {
        rethrow;
      }
      throw LauncherException('Error creating Windows shortcut', e.toString());
    }
  }

  @override
  Future<String?> findEdenExecutable(String installPath, String channel) async {
    LoggingService.info('Finding Eden executable in Windows installation');
    LoggingService.info('Install path: $installPath');
    LoggingService.info('Channel: $channel');

    try {
      // First, try the channel-specific installation path
      final channelInstallPath = await _installationService
          .getChannelInstallPath();
      final fileHandler = WindowsFileHandler();
      final expectedPath = fileHandler.getEdenExecutablePath(
        channelInstallPath,
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
          final fileHandler = WindowsFileHandler();
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
      LoggingService.error('Error finding Eden executable on Windows', e);
      return null;
    }
  }
}
