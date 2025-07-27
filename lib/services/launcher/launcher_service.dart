import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/logging_service.dart';
import '../../core/utils/file_utils.dart';
import '../storage/preferences_service.dart';
import '../installation/installation_service.dart';

/// Service for launching Eden emulator
class LauncherService {
  final PreferencesService _preferencesService;
  final InstallationService _installationService;

  LauncherService(this._preferencesService, this._installationService);

  /// Launch the Eden emulator
  Future<void> launchEden() async {
    // On Android, use Android-specific launch method
    if (Platform.isAndroid) {
      await _launchEdenAndroid();
      return;
    }

    // Desktop launch logic
    final channel = await _preferencesService.getReleaseChannel();
    String? edenExecutable = await _preferencesService.getEdenExecutablePath(
      channel,
    );

    if (edenExecutable == null || !await File(edenExecutable).exists()) {
      final installPath = await _installationService.getInstallPath();
      edenExecutable = FileUtils.getEdenExecutablePath(installPath, channel);
    }

    if (!await File(edenExecutable).exists()) {
      throw LauncherException(
        'Eden is not installed',
        'Please download Eden first before launching',
      );
    }

    try {
      await Process.start(edenExecutable, [], mode: ProcessStartMode.detached);
    } catch (e) {
      throw LauncherException(
        'Failed to launch Eden',
        'Error starting Eden: ${e.toString()}',
      );
    }
  }

  /// Launch Eden on Android by trying to find the installed APK
  Future<void> _launchEdenAndroid() async {
    LoggingService.info('Attempting to launch Eden on Android');

    // Get the channel to check if we have installation metadata
    final channel = await _preferencesService.getReleaseChannel();

    // Check if we have stored installation metadata
    final metadataString = await _preferencesService.getString(
      'android_install_metadata_$channel',
    );
    if (metadataString == null) {
      LoggingService.warning(
        'No Android installation metadata found for channel: $channel',
      );
      throw LauncherException(
        'Eden not found',
        'No Eden installation detected. Please install Eden first.',
      );
    }

    // Try to launch Eden using the correct package name
    final possiblePackageNames = [
      // Correct Eden package name
      'dev.eden.eden_emulator',
      // Fallback variations just in case
      'org.eden.emulator',
      'com.eden.emulator',
      'eden.emulator',
    ];

    bool launched = false;
    String? successfulPackage;

    for (final packageName in possiblePackageNames) {
      try {
        LoggingService.info('Trying to launch package: $packageName');

        // Method 1: Try using url_launcher with app-specific URI
        try {
          // For Eden, try to launch directly using app URI
          if (packageName == 'dev.eden.eden_emulator') {
            final uri = Uri.parse('android-app://dev.eden.eden_emulator');
            final canLaunch = await canLaunchUrl(uri);
            LoggingService.info(
              'canLaunchUrl app URI for $packageName: $canLaunch',
            );

            if (canLaunch) {
              final result = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (result) {
                LoggingService.info(
                  'Successfully launched Eden Android app via app URI: $packageName',
                );
                successfulPackage = packageName;
                launched = true;
                break;
              }
            }
          }

          // Fallback to package URI
          final uri = Uri.parse('package:$packageName');
          final canLaunch = await canLaunchUrl(uri);
          LoggingService.info('canLaunchUrl for $packageName: $canLaunch');

          if (canLaunch) {
            final result = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (result) {
              LoggingService.info(
                'Successfully launched Eden Android app via url_launcher: $packageName',
              );
              successfulPackage = packageName;
              launched = true;
              break;
            }
          }
        } catch (e) {
          LoggingService.info('url_launcher failed for $packageName: $e');
        }

        // Method 2: Try using Android Intent directly
        if (!launched) {
          try {
            LoggingService.info('Trying Android Intent for $packageName');

            // Create launch intent for the package
            AndroidIntent intent;

            // Try to launch the app using its launch intent
            if (packageName == 'dev.eden.eden_emulator') {
              // Use a more direct approach for Eden
              intent = AndroidIntent(
                action: 'android.intent.action.MAIN',
                package: 'dev.eden.eden_emulator',
                flags: <int>[
                  0x10000000, // FLAG_ACTIVITY_NEW_TASK
                  0x00000020, // FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                ],
              );
            } else {
              // Generic launcher intent for fallback packages
              intent = AndroidIntent(
                action: 'android.intent.action.MAIN',
                package: packageName,
                category: 'android.intent.category.LAUNCHER',
                flags: <int>[
                  0x10000000, // FLAG_ACTIVITY_NEW_TASK
                  0x00000020, // FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                ],
              );
            }

            await intent.launch();
            LoggingService.info(
              'Successfully launched Eden Android app via Intent: $packageName',
            );
            successfulPackage = packageName;
            launched = true;
            break;
          } catch (e) {
            LoggingService.info('Android Intent failed for $packageName: $e');
          }
        }
      } catch (e) {
        LoggingService.info('All launch methods failed for $packageName: $e');
        // Try next package name
        continue;
      }
    }

    if (!launched) {
      LoggingService.warning(
        'Could not launch Eden Android app - no matching package found',
      );

      // Try alternative launch method - open the APK file directly
      await _tryLaunchFromApkFile();
    } else if (successfulPackage != null) {
      // Store the successful package name for future launches
      await _preferencesService.setString(
        'android_successful_package',
        successfulPackage,
      );
    }
  }

  /// Try to launch Eden by opening the APK file from Downloads
  Future<void> _tryLaunchFromApkFile() async {
    try {
      LoggingService.info('Trying to launch Eden from APK file');

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        await for (final entity in downloadsDir.list()) {
          if (entity is File &&
              entity.path.toLowerCase().contains('eden') &&
              entity.path.toLowerCase().endsWith('.apk')) {
            LoggingService.info('Found Eden APK: ${entity.path}');

            // Try to open the APK file (this will show the app info or launch it)
            final uri = Uri.parse('file://${entity.path}');
            final canLaunch = await canLaunchUrl(uri);

            if (canLaunch) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              LoggingService.info('Opened Eden APK file');
              return;
            }
          }
        }
      }

      // If we get here, we couldn't find or launch the APK
      throw LauncherException(
        'Eden not found',
        'Eden appears to be installed but cannot be launched. '
            'Please check your app drawer for "Eden" or try reinstalling.',
      );
    } catch (e) {
      LoggingService.error('Failed to launch Eden from APK file', e);
      throw LauncherException(
        'Launch failed',
        'Could not launch Eden. Please check if Eden is properly installed and try launching it manually from your app drawer.',
      );
    }
  }

  /// Create a desktop shortcut for Eden
  Future<void> createDesktopShortcut() async {
    if (Platform.isWindows) {
      await _createWindowsShortcut();
    }
    if (Platform.isLinux) {
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
        if (desktopPaths.isEmpty) return;

        final shortcutContent = _generateDesktopEntry(edenExecutable, channel);
        final shortcutName = channel == 'nightly'
            ? 'Eden-Nightly.desktop'
            : 'Eden.desktop';

        for (final desktopPath in desktopPaths) {
          try {
            final shortcutFile = File(path.join(desktopPath, shortcutName));
            await shortcutFile.writeAsString(shortcutContent);

            // Make the desktop file executable
            await Process.run('chmod', ['+x', shortcutFile.path]);
          } catch (e) {
            // Continue to next path if this one fails
            continue;
          }
        }
      } catch (e) {
        throw LauncherException(
          'Failed to create desktop shortcut',
          e.toString(),
        );
      }
    }
  }

  Future<void> _createWindowsShortcut() async {
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

      // Get desktop path
      final result = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetFolderPath("Desktop")',
      ]);

      if (result.exitCode != 0) {
        throw LauncherException(
          'Failed to get desktop path',
          result.stderr.toString(),
        );
      }

      final desktopPath = result.stdout.toString().trim();
      final shortcutPath = path.join(desktopPath, shortcutName);

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
    } catch (e) {
      if (e is LauncherException) rethrow;
      throw LauncherException('Error creating Windows shortcut', e.toString());
    }
  }

  String _generateDesktopEntry(String executablePath, String channel) {
    final name = channel == 'nightly' ? 'Eden Nightly' : 'Eden';
    final comment = channel == 'nightly'
        ? 'Nintendo Switch Emulator (Nightly Build)'
        : 'Nintendo Switch Emulator';

    return '''[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$executablePath
Icon=applications-games
Terminal=false
Categories=Game;Emulator;
''';
  }

  Future<List<String>> _getDesktopPaths() async {
    final paths = <String>[];

    try {
      // Get user's home directory
      final homeDir = Platform.environment['HOME'] ?? '';
      if (homeDir.isNotEmpty) {
        paths.addAll([
          path.join(homeDir, 'Desktop'),
          path.join(homeDir, '.local', 'share', 'applications'),
        ]);
      }

      // Add system-wide paths
      paths.addAll([
        '/usr/share/applications',
        '/usr/local/share/applications',
      ]);

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
        // Ignore errors and use default paths
      }
    } catch (e) {
      // Ignore errors and use default paths
    }

    return paths;
  }
}
