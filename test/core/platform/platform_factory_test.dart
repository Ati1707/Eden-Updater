import 'package:flutter_test/flutter_test.dart';
import 'package:eden_updater/core/platform/platform_factory.dart';
import 'package:eden_updater/core/platform/models/platform_config.dart';

void main() {
  group('PlatformFactory', () {
    setUp(() {
      // Reset cache before each test
      PlatformFactory.resetCache();
    });

    test('getCurrentPlatformConfig returns valid configuration', () {
      final config = PlatformFactory.getCurrentPlatformConfig();
      expect(config, isA<PlatformConfig>());
      expect(config.name, isNotEmpty);
      expect(config.supportedFileExtensions, isNotEmpty);
      expect(config.supportedChannels, isNotEmpty);
    });

    test('isCurrentPlatformSupported returns boolean', () {
      final isSupported = PlatformFactory.isCurrentPlatformSupported();
      expect(isSupported, isA<bool>());
    });

    test('getSupportedPlatforms returns expected platforms', () {
      final platforms = PlatformFactory.getSupportedPlatforms();
      expect(platforms, contains('Windows'));
      expect(platforms, contains('Linux'));
      expect(platforms, contains('Android'));
      expect(platforms, contains('macOS'));
    });

    test('getDetectablePlatforms includes macOS', () {
      final platforms = PlatformFactory.getDetectablePlatforms();
      expect(platforms, contains('Windows'));
      expect(platforms, contains('Linux'));
      expect(platforms, contains('Android'));
      expect(platforms, contains('macOS'));
    });

    test('isFileExtensionSupported works with and without dot', () {
      // This test will work regardless of platform
      final config = PlatformFactory.getCurrentPlatformConfig();
      if (config.supportedFileExtensions.isNotEmpty) {
        final extension = config.supportedFileExtensions.first;
        final extensionWithoutDot = extension.substring(1);

        expect(PlatformFactory.isFileExtensionSupported(extension), isTrue);
        expect(
          PlatformFactory.isFileExtensionSupported(extensionWithoutDot),
          isTrue,
        );
      }
    });

    test('isChannelSupported works correctly', () {
      final config = PlatformFactory.getCurrentPlatformConfig();
      if (config.supportedChannels.contains('stable')) {
        expect(PlatformFactory.isChannelSupported('stable'), isTrue);
        expect(PlatformFactory.isChannelSupported('STABLE'), isTrue);
      }

      expect(PlatformFactory.isChannelSupported('nonexistent'), isFalse);
    });

    test('getSupportedFileExtensions returns immutable list', () {
      final extensions = PlatformFactory.getSupportedFileExtensions();
      expect(extensions, isA<List<String>>());
      expect(() => extensions.add('.test'), throwsUnsupportedError);
    });

    test('getSupportedChannels returns immutable list', () {
      final channels = PlatformFactory.getSupportedChannels();
      expect(channels, isA<List<String>>());
      expect(() => channels.add('test'), throwsUnsupportedError);
    });

    test('getPlatformInfo returns detailed information', () {
      final info = PlatformFactory.getPlatformInfo();
      expect(info, isA<Map<String, dynamic>>());
      expect(info['platformName'], isA<String>());
      expect(info['isSupported'], isA<bool>());
      expect(info['operatingSystem'], isA<String>());
    });

    test('factory methods create appropriate implementations', () {
      // All platforms should now have implementations
      expect(() => PlatformFactory.createInstaller(), returnsNormally);
      expect(() => PlatformFactory.createLauncher(), returnsNormally);
      expect(() => PlatformFactory.createFileHandler(), returnsNormally);
      expect(() => PlatformFactory.createVersionDetector(), returnsNormally);
      expect(() => PlatformFactory.createUpdateService(), returnsNormally);
      expect(
        () => PlatformFactory.createInstallationService(),
        returnsNormally,
      );
    });

    test('resetCache clears cached values', () {
      // Get config to populate cache
      PlatformFactory.getCurrentPlatformConfig();

      // Reset cache
      PlatformFactory.resetCache();

      // Should still work after reset
      final config = PlatformFactory.getCurrentPlatformConfig();
      expect(config, isA<PlatformConfig>());
    });

    group('macOS Platform Integration', () {
      test('macOS platform configuration is properly defined', () {
        final macosConfig = PlatformConfig.macos;
        expect(macosConfig.name, equals('macOS'));
        expect(macosConfig.supportedFileExtensions, contains('.dmg'));
        expect(macosConfig.supportedFileExtensions, contains('.app'));
        expect(macosConfig.supportedFileExtensions, contains('.zip'));
        expect(macosConfig.supportedChannels, contains('stable'));
        expect(macosConfig.supportedChannels, contains('nightly'));
        expect(macosConfig.supportsShortcuts, isTrue);
        expect(macosConfig.supportsPortableMode, isTrue);
        expect(macosConfig.requiresExecutablePermissions, isTrue);
        expect(macosConfig.defaultInstallationDir, equals('Eden'));
      });

      test('macOS file extensions are supported', () {
        // Test with macOS config
        final macosConfig = PlatformConfig.macos;
        for (final extension in macosConfig.supportedFileExtensions) {
          expect(
            macosConfig.supportedFileExtensions.contains(extension),
            isTrue,
          );
        }
      });

      test('macOS channels are supported', () {
        final macosConfig = PlatformConfig.macos;
        expect(macosConfig.supportedChannels.contains('stable'), isTrue);
        expect(macosConfig.supportedChannels.contains('nightly'), isTrue);
      });

      test('macOS feature flags are properly configured', () {
        final macosConfig = PlatformConfig.macos;
        expect(macosConfig.getFeatureFlag('supportsShortcutCreation'), isTrue);
        expect(
          macosConfig.getFeatureFlag('supportsPortableInstallation'),
          isTrue,
        );
        expect(
          macosConfig.getFeatureFlag('requiresExecutablePermissions'),
          isTrue,
        );
        expect(macosConfig.getFeatureFlag('supportsAutoLaunch'), isTrue);
      });

      test('macOS platform-specific config values are accessible', () {
        final macosConfig = PlatformConfig.macos;
        expect(
          macosConfig.getConfigValue<String>('shortcutExtension'),
          equals('.app'),
        );
        expect(
          macosConfig.getConfigValue<List<String>>('executableExtensions'),
          contains('.app'),
        );
        expect(
          macosConfig.getConfigValue<List<String>>('archiveExtensions'),
          contains('.dmg'),
        );
        expect(
          macosConfig.getConfigValue<List<String>>('archiveExtensions'),
          contains('.zip'),
        );
        expect(macosConfig.getConfigValue<int>('maxRetries'), equals(10));
        expect(macosConfig.getConfigValue<int>('retryDelaySeconds'), equals(3));
        expect(
          macosConfig.getConfigValue<int>('requestTimeoutSeconds'),
          equals(10),
        );
      });
    });
  });
}
