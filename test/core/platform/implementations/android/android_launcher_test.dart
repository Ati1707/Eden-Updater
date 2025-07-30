import 'package:flutter_test/flutter_test.dart';

import 'package:eden_updater/core/platform/implementations/android/android_launcher.dart';
import 'package:eden_updater/core/platform/exceptions/platform_exceptions.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidLauncher', () {
    late AndroidLauncher launcher;
    late PreferencesService preferencesService;

    setUp(() {
      preferencesService = PreferencesService();
      launcher = AndroidLauncher(preferencesService);
    });

    group('launchEden', () {
      test('throws exception when no installation metadata found', () async {
        // In test environment, no Android metadata will be found
        expect(
          () => launcher.launchEden(),
          throwsA(isA<PlatformOperationException>()),
        );
      });
    });

    group('createDesktopShortcut', () {
      test('completes without error (no-op on Android)', () async {
        // Should complete without throwing
        await launcher.createDesktopShortcut();
      });
    });

    group('findEdenExecutable', () {
      test('returns null when no packages are installed', () async {
        // In test environment, no Android packages will be found
        final result = await launcher.findEdenExecutable(
          '/test/path',
          'stable',
        );

        expect(result, isNull);
      });

      test('handles different install paths and channels', () async {
        // Test with different parameters
        final result1 = await launcher.findEdenExecutable(
          '/test/path1',
          'stable',
        );
        final result2 = await launcher.findEdenExecutable(
          '/test/path2',
          'nightly',
        );

        // In test environment, both should return null
        expect(result1, isNull);
        expect(result2, isNull);
      });
    });

    group('Android-specific functionality', () {
      test('constructor creates instance successfully', () {
        expect(launcher, isNotNull);
        expect(launcher, isA<AndroidLauncher>());
      });
    });
  });
}
