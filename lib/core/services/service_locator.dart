import '../../services/update_service.dart';
import '../../services/network/github_api_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/download/download_service.dart';
import '../../services/extraction/extraction_service.dart';
import '../../services/installation/installation_service.dart';
import '../../services/launcher/launcher_service.dart';
import '../platform/platform_factory.dart';
import 'logging_service.dart';

/// Simple service locator for dependency injection
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};

  /// Register a service
  void register<T>(T service) {
    _services[T] = service;
  }

  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T not registered');
    }
    return service as T;
  }

  /// Initialize all services
  static void initialize() {
    LoggingService.info('[ServiceLocator] Initializing services...');

    final locator = ServiceLocator();

    // Get platform information for logging
    final platformInfo = PlatformFactory.getPlatformInfo();
    LoggingService.info(
      '[ServiceLocator] Platform: ${platformInfo['platformName']}',
    );
    LoggingService.debug(
      '[ServiceLocator] Platform supported: ${platformInfo['isSupported']}',
    );
    LoggingService.debug(
      '[ServiceLocator] Platform capabilities: ${platformInfo['supportedChannels']}',
    );

    // Register core services as singletons
    LoggingService.debug('[ServiceLocator] Creating core services...');
    final preferencesService = PreferencesService();
    final fileHandler = PlatformFactory.createFileHandler();

    LoggingService.debug('[ServiceLocator] Registering PreferencesService');
    locator.register<PreferencesService>(preferencesService);

    LoggingService.debug('[ServiceLocator] Registering GitHubApiService');
    locator.register<GitHubApiService>(GitHubApiService());

    LoggingService.debug('[ServiceLocator] Registering DownloadService');
    locator.register<DownloadService>(DownloadService());

    LoggingService.debug(
      '[ServiceLocator] Registering ExtractionService with platform file handler',
    );
    locator.register<ExtractionService>(ExtractionService(fileHandler));

    // Register services that depend on others
    LoggingService.debug('[ServiceLocator] Creating dependent services...');
    final installationService = InstallationService(
      preferencesService,
      fileHandler,
    );
    LoggingService.debug('[ServiceLocator] Registering InstallationService');
    locator.register<InstallationService>(installationService);

    LoggingService.debug('[ServiceLocator] Registering LauncherService');
    locator.register<LauncherService>(
      LauncherService(preferencesService, installationService),
    );

    // Register platform-specific services as singletons
    LoggingService.debug(
      '[ServiceLocator] Creating platform-specific services...',
    );
    final platformInstaller = PlatformFactory.createInstaller();
    final platformVersionDetector = PlatformFactory.createVersionDetector();
    final platformUpdateService =
        PlatformFactory.createUpdateServiceWithServices(preferencesService);

    // Register the main update service
    LoggingService.debug(
      '[ServiceLocator] Registering UpdateService with platform implementations',
    );
    locator.register<UpdateService>(
      UpdateService.withServices(
        locator.get<GitHubApiService>(),
        preferencesService,
        locator.get<DownloadService>(),
        locator.get<LauncherService>(),
        platformInstaller,
        platformVersionDetector,
        platformUpdateService,
      ),
    );

    LoggingService.info(
      '[ServiceLocator] Service initialization completed successfully',
    );
    LoggingService.debug(
      '[ServiceLocator] Registered services: ${locator._services.keys.map((k) => k.toString()).join(', ')}',
    );
  }
}
