import '../../services/update_service.dart';
import '../../services/network/github_api_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/download/download_service.dart';
import '../../services/extraction/extraction_service.dart';
import '../../services/installation/installation_service.dart';
import '../../services/launcher/launcher_service.dart';

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

  /// Get a service
  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T not registered');
    }
    return service as T;
  }

  /// Check if a service is registered
  bool isRegistered<T>() => _services.containsKey(T);

  /// Initialize all services
  static void initialize() {
    final locator = ServiceLocator();

    // Register core services
    locator.register<PreferencesService>(PreferencesService());
    locator.register<GitHubApiService>(GitHubApiService());
    locator.register<DownloadService>(DownloadService());
    locator.register<ExtractionService>(ExtractionService());

    // Register services that depend on others
    final preferencesService = locator.get<PreferencesService>();
    locator.register<InstallationService>(
      InstallationService(preferencesService),
    );

    final installationService = locator.get<InstallationService>();
    locator.register<LauncherService>(
      LauncherService(preferencesService, installationService),
    );

    // Register the main update service
    locator.register<UpdateService>(
      UpdateService.withServices(
        locator.get<GitHubApiService>(),
        preferencesService,
        locator.get<DownloadService>(),
        locator.get<ExtractionService>(),
        installationService,
        locator.get<LauncherService>(),
      ),
    );
  }

  /// Clear all services (useful for testing)
  void clear() {
    _services.clear();
  }
}
