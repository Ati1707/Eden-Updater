import '../../core/services/logging_service.dart';
import '../../core/platform/platform_factory.dart';
import '../../core/platform/interfaces/i_platform_launcher.dart';
import '../storage/preferences_service.dart';
import '../installation/installation_service.dart';

class LauncherService {
  final IPlatformLauncher _platformLauncher;

  LauncherService(
    PreferencesService preferencesService,
    InstallationService installationService,
  ) : _platformLauncher = PlatformFactory.createLauncherWithServices(
        preferencesService,
        installationService,
      );

  Future<void> launchEden() async {
    try {
      LoggingService.info('Launching Eden using platform abstraction');
      await _platformLauncher.launchEden();
      LoggingService.info('Eden launched successfully');
    } catch (e) {
      LoggingService.error('Failed to launch Eden', e);
      rethrow;
    }
  }

  Future<void> createDesktopShortcut() async {
    try {
      LoggingService.info(
        'Creating desktop shortcut using platform abstraction',
      );
      await _platformLauncher.createDesktopShortcut();
      LoggingService.info('Desktop shortcut created successfully');
    } catch (e) {
      LoggingService.error('Failed to create desktop shortcut', e);
      rethrow;
    }
  }

  Future<String?> findEdenExecutable(String installPath, String channel) async {
    try {
      LoggingService.info('Finding Eden executable using platform abstraction');
      final result = await _platformLauncher.findEdenExecutable(
        installPath,
        channel,
      );
      if (result != null) {
        LoggingService.info('Eden executable found: $result');
      } else {
        LoggingService.warning('Eden executable not found');
      }
      return result;
    } catch (e) {
      LoggingService.error('Error finding Eden executable', e);
      return null;
    }
  }
}
