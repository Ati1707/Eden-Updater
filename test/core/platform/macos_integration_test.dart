import 'package:flutter_test/flutter_test.dart';
import 'package:eden_updater/core/platform/platform_factory.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_installer.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_launcher.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_file_handler.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_version_detector.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_update_service.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_installation_service.dart';
import 'package:eden_updater/core/platform/models/installation_context.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/models/update_info.dart';

void main() {
  group('macOS Platform Integration Tests', () {
    setUp(() {
      // Reset cache before each test
      PlatformFactory.resetCache();
    });

    test('macOS installer can be instantiated through factory', () {
      // This test verifies that the factory can create macOS implementations
      // even when not running on macOS (for CI/CD purposes)
      expect(() {
        final installer = PlatformFactory.createInstaller();
        expect(installer, isA<IPlatformInstaller>());
      }, returnsNormally);
    });

    test('macOS launcher can be instantiated through factory', () {
      expect(() {
        final launcher = PlatformFactory.createLauncher();
        expect(launcher, isA<IPlatformLauncher>());
      }, returnsNormally);
    });

    test('macOS file handler can be instantiated through factory', () {
      expect(() {
        final fileHandler = PlatformFactory.createFileHandler();
        expect(fileHandler, isA<IPlatformFileHandler>());
      }, returnsNormally);
    });

    test('macOS version detector can be instantiated through factory', () {
      expect(() {
        final versionDetector = PlatformFactory.createVersionDetector();
        expect(versionDetector, isA<IPlatformVersionDetector>());
      }, returnsNormally);
    });

    test('macOS update service can be instantiated through factory', () {
      expect(() {
        final updateService = PlatformFactory.createUpdateService();
        expect(updateService, isA<IPlatformUpdateService>());
      }, returnsNormally);
    });

    test('macOS installation service can be instantiated through factory', () {
      expect(() {
        final installationService = PlatformFactory.createInstallationService();
        expect(installationService, isA<IPlatformInstallationService>());
      }, returnsNormally);
    });

    test('macOS factory methods with dependency injection work correctly', () {
      expect(() {
        final preferencesService = PreferencesService();
        final fileHandler = PlatformFactory.createFileHandler();

        // Test update service with services
        final updateService = PlatformFactory.createUpdateServiceWithServices(
          preferencesService,
        );
        expect(updateService, isA<IPlatformUpdateService>());

        // Test installation service with services
        final installationService =
            PlatformFactory.createInstallationServiceWithServices(
              fileHandler,
              preferencesService,
            );
        expect(installationService, isA<IPlatformInstallationService>());
      }, returnsNormally);
    });

    test('macOS installation context validation works correctly', () {
      // Create a mock UpdateInfo for testing
      final mockUpdateInfo = UpdateInfo(
        version: '1.0.0',
        downloadUrl: 'https://example.com/eden.dmg',
        releaseNotes: 'Test release',
        releaseDate: DateTime.now(),
        fileSize: 1024,
        releaseUrl: 'https://example.com/release',
      );

      // Test valid contexts
      expect(() {
        final context = InstallationContext(
          filePath: '/path/to/eden.dmg',
          installPath: '/Applications/Eden.app',
          updateInfo: mockUpdateInfo,
          channel: 'stable',
          createShortcuts: true,
          portableMode: true,
          onProgress: (progress) {},
          onStatusUpdate: (status) {},
        );
        PlatformFactory.validateInstallationContext(context);
      }, returnsNormally);

      expect(() {
        final context = InstallationContext(
          filePath: '/path/to/eden.app',
          installPath: '/Applications/Eden.app',
          updateInfo: mockUpdateInfo,
          channel: 'nightly',
          createShortcuts: true,
          portableMode: false,
          onProgress: (progress) {},
          onStatusUpdate: (status) {},
        );
        PlatformFactory.validateInstallationContext(context);
      }, returnsNormally);
    });

    test('macOS platform detection and configuration work correctly', () {
      final platformInfo = PlatformFactory.getPlatformInfo();
      expect(platformInfo, isA<Map<String, dynamic>>());
      expect(platformInfo['platformName'], isA<String>());
      expect(platformInfo['isSupported'], isA<bool>());

      // Verify macOS-specific configuration is accessible
      if (platformInfo['platformName'] == 'macOS') {
        expect(platformInfo['supportedExtensions'], contains('.dmg'));
        expect(platformInfo['supportedExtensions'], contains('.app'));
        expect(platformInfo['supportedExtensions'], contains('.zip'));
        expect(platformInfo['supportedChannels'], contains('stable'));
        expect(platformInfo['supportedChannels'], contains('nightly'));
        expect(platformInfo['supportsShortcuts'], isTrue);
        expect(platformInfo['supportsPortableMode'], isTrue);
        expect(platformInfo['requiresExecutablePermissions'], isTrue);
        expect(platformInfo['defaultInstallationDir'], equals('Eden'));
      }
    });

    test('macOS file extension and channel support detection works', () {
      // Test file extension support
      expect(PlatformFactory.isFileExtensionSupported('.dmg'), isA<bool>());
      expect(PlatformFactory.isFileExtensionSupported('dmg'), isA<bool>());
      expect(PlatformFactory.isFileExtensionSupported('.app'), isA<bool>());
      expect(PlatformFactory.isFileExtensionSupported('app'), isA<bool>());
      expect(PlatformFactory.isFileExtensionSupported('.zip'), isA<bool>());
      expect(PlatformFactory.isFileExtensionSupported('zip'), isA<bool>());

      // Test channel support
      expect(PlatformFactory.isChannelSupported('stable'), isA<bool>());
      expect(PlatformFactory.isChannelSupported('nightly'), isA<bool>());
      expect(PlatformFactory.isChannelSupported('STABLE'), isA<bool>());
      expect(PlatformFactory.isChannelSupported('NIGHTLY'), isA<bool>());
    });

    test('macOS supported platforms and extensions lists include macOS', () {
      final supportedPlatforms = PlatformFactory.getSupportedPlatforms();
      expect(supportedPlatforms, contains('macOS'));

      final detectablePlatforms = PlatformFactory.getDetectablePlatforms();
      expect(detectablePlatforms, contains('macOS'));

      final supportedExtensions = PlatformFactory.getSupportedFileExtensions();
      expect(supportedExtensions, isA<List<String>>());

      final supportedChannels = PlatformFactory.getSupportedChannels();
      expect(supportedChannels, isA<List<String>>());
    });

    test('macOS platform is marked as supported', () {
      expect(PlatformFactory.isCurrentPlatformSupported(), isA<bool>());

      // The list of supported platforms should include macOS
      final supportedPlatforms = PlatformFactory.getSupportedPlatforms();
      expect(
        supportedPlatforms.length,
        equals(4),
      ); // Windows, Linux, Android, macOS
      expect(
        supportedPlatforms,
        containsAll(['Windows', 'Linux', 'Android', 'macOS']),
      );
    });
  });
}
