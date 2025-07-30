import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../services/logging_service.dart';
import '../platform/platform_factory.dart';

class UrlLauncherUtils {
  UrlLauncherUtils._();
  static Future<bool> launchUrlRobust(String url) async {
    try {
      LoggingService.info('Attempting to launch URL: $url');
      final uri = Uri.parse(url);
      final platformConfig = PlatformFactory.getCurrentPlatformConfig();

      switch (platformConfig.name) {
        case 'Linux':
          return await _launchUrlLinux(uri);
        case 'Android':
          return await _launchUrlAndroid(uri, url);
        case 'Windows':
          return await _launchUrlWindows(uri);
        default:
          return await _launchUrlGeneric(uri);
      }
    } catch (e) {
      LoggingService.error('Failed to launch URL: $url', e);
      return false;
    }
  }

  static Future<bool> _launchUrlLinux(Uri uri) async {
    LoggingService.debug('Using Linux-specific URL launching');

    // Method 1: Try with explicit browser command to avoid display server issues
    try {
      LoggingService.debug('Trying direct browser launch...');

      // Try common Linux browsers in order of preference
      final browsers = [
        'xdg-open',
        'firefox',
        'chromium-browser',
        'chromium',
        'google-chrome',
        'opera',
        'brave-browser',
      ];

      for (final browser in browsers) {
        try {
          final result = await Process.run('which', [browser]);
          if (result.exitCode == 0) {
            LoggingService.debug('Found browser: $browser');

            // Create a clean environment to avoid display server conflicts
            final env = Map<String, String>.from(Platform.environment);

            // Handle Wayland display server issues
            if (env['WAYLAND_DISPLAY'] != null) {
              LoggingService.debug(
                'Detected Wayland environment: WAYLAND_DISPLAY=${env['WAYLAND_DISPLAY']}',
              );

              // For browsers that might have issues with Wayland, try X11 fallback
              if (env['DISPLAY'] != null) {
                LoggingService.debug(
                  'X11 fallback available: DISPLAY=${env['DISPLAY']}, prioritizing X11',
                );
                // Temporarily unset WAYLAND_DISPLAY to force X11 usage
                env.remove('WAYLAND_DISPLAY');
                LoggingService.debug(
                  'Removed WAYLAND_DISPLAY, using X11 for browser launch',
                );
              } else {
                LoggingService.debug(
                  'No X11 fallback available, keeping Wayland',
                );
              }
            }

            // Launch browser with modified environment
            final browserResult = await Process.run(
              browser,
              [uri.toString()],
              environment: env,
              runInShell: true,
            );

            if (browserResult.exitCode == 0) {
              LoggingService.info('Successfully launched URL with $browser');
              return true;
            } else {
              LoggingService.debug(
                'Browser $browser failed with exit code: ${browserResult.exitCode}',
              );
              if (browserResult.stderr.isNotEmpty) {
                LoggingService.debug('Browser stderr: ${browserResult.stderr}');
              }
            }
          }
        } catch (e) {
          LoggingService.debug('Browser $browser not available: $e');
          continue;
        }
      }
    } catch (e) {
      LoggingService.debug('Direct browser launch failed: $e');
    }

    // Method 2: Try system default with shell execution
    try {
      LoggingService.debug('Trying system shell execution...');
      final env = Map<String, String>.from(Platform.environment);

      // Remove Wayland display to avoid conflicts
      if (env['WAYLAND_DISPLAY'] != null && env['DISPLAY'] != null) {
        env.remove('WAYLAND_DISPLAY');
        LoggingService.debug('Removed WAYLAND_DISPLAY for shell execution');
      }

      final result = await Process.run('sh', [
        '-c',
        'xdg-open "${uri.toString()}" || firefox "${uri.toString()}" || chromium "${uri.toString()}"',
      ], environment: env);

      if (result.exitCode == 0) {
        LoggingService.info('Successfully launched URL with shell execution');
        return true;
      }
    } catch (e) {
      LoggingService.debug('Shell execution failed: $e');
    }

    LoggingService.warning('All Linux URL launch methods failed');
    return false;
  }

  static Future<bool> _launchUrlAndroid(Uri uri, String url) async {
    LoggingService.debug('Using Android-specific URL launching');

    // Method 1: Try url_launcher with external application mode
    try {
      LoggingService.debug('Trying url_launcher external application mode...');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LoggingService.info(
          'Successfully launched URL with url_launcher external mode',
        );
        return true;
      }
    } catch (e) {
      LoggingService.debug('url_launcher external mode failed: $e');
    }

    // Method 2: Try Android Intent
    try {
      LoggingService.debug('Trying Android Intent...');
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
        flags: <int>[0x10000000], // FLAG_ACTIVITY_NEW_TASK
      );
      await intent.launch();
      LoggingService.info('Successfully launched URL with Android Intent');
      return true;
    } catch (e) {
      LoggingService.debug('Android Intent failed: $e');
    }

    // Method 3: Try url_launcher platform default
    try {
      LoggingService.debug('Trying url_launcher platform default mode...');
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      LoggingService.info(
        'Successfully launched URL with url_launcher platform default',
      );
      return true;
    } catch (e) {
      LoggingService.debug('url_launcher platform default failed: $e');
    }

    LoggingService.warning('All Android URL launch methods failed');
    return false;
  }

  static Future<bool> _launchUrlWindows(Uri uri) async {
    LoggingService.debug('Using Windows-specific URL launching');

    // Method 1: Try url_launcher with external application mode
    try {
      LoggingService.debug('Trying url_launcher external application mode...');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LoggingService.info(
          'Successfully launched URL with url_launcher external mode',
        );
        return true;
      }
    } catch (e) {
      LoggingService.debug('url_launcher external mode failed: $e');
    }

    // Method 2: Try direct Windows command
    try {
      LoggingService.debug('Trying Windows start command...');
      final result = await Process.run('cmd', ['/c', 'start', uri.toString()]);
      if (result.exitCode == 0) {
        LoggingService.info(
          'Successfully launched URL with Windows start command',
        );
        return true;
      }
    } catch (e) {
      LoggingService.debug('Windows start command failed: $e');
    }

    // Method 3: Try url_launcher platform default
    try {
      LoggingService.debug('Trying url_launcher platform default mode...');
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      LoggingService.info(
        'Successfully launched URL with url_launcher platform default',
      );
      return true;
    } catch (e) {
      LoggingService.debug('url_launcher platform default failed: $e');
    }

    LoggingService.warning('All Windows URL launch methods failed');
    return false;
  }

  static Future<bool> _launchUrlGeneric(Uri uri) async {
    LoggingService.debug('Using generic URL launching');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LoggingService.info('Successfully launched URL with generic method');
        return true;
      }
    } catch (e) {
      LoggingService.debug('Generic URL launch failed: $e');
    }

    return false;
  }

  static Future<void> copyUrlToClipboard(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      LoggingService.info('URL copied to clipboard: $url');
    } catch (e) {
      LoggingService.error('Failed to copy URL to clipboard', e);
    }
  }
}
