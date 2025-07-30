import 'package:flutter_test/flutter_test.dart';
import 'package:eden_updater/core/platform/platform_factory.dart';
import 'package:eden_updater/core/platform/models/platform_config.dart';
import 'package:eden_updater/core/platform/exceptions/platform_exceptions.dart';

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

    test(
      'factory methods throw appropriate exceptions for unimplemented platforms',
      () {
        expect(
          () => PlatformFactory.createInstaller(),
          throwsA(isA<PlatformOperationException>()),
        );

        expect(
          () => PlatformFactory.createLauncher(),
          throwsA(isA<PlatformOperationException>()),
        );

        expect(
          () => PlatformFactory.createFileHandler(),
          throwsA(isA<PlatformOperationException>()),
        );

        expect(
          () => PlatformFactory.createVersionDetector(),
          throwsA(isA<PlatformOperationException>()),
        );
      },
    );

    test('resetCache clears cached values', () {
      // Get config to populate cache
      PlatformFactory.getCurrentPlatformConfig();

      // Reset cache
      PlatformFactory.resetCache();

      // Should still work after reset
      final config = PlatformFactory.getCurrentPlatformConfig();
      expect(config, isA<PlatformConfig>());
    });
  });
}
