import 'package:flutter_test/flutter_test.dart';

import 'package:eden_updater/core/platform/implementations/android/android_version_detector.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidVersionDetector', () {
    late AndroidVersionDetector versionDetector;
    late PreferencesService preferencesService;

    setUp(() {
      preferencesService = PreferencesService();
      versionDetector = AndroidVersionDetector(preferencesService);
    });

    group('getCurrentVersion', () {
      test('returns null when no version information is stored', () async {
        // In test environment with no SharedPreferences plugin, this will return null
        final result = await versionDetector.getCurrentVersion('stable');

        expect(result, isNull);
      });
    });

    group('Android-specific functionality', () {
      test('constructor creates instance successfully', () {
        expect(versionDetector, isNotNull);
        expect(versionDetector, isA<AndroidVersionDetector>());
      });

      test('handles different channels', () async {
        // Test that the detector can handle different channel names
        final result1 = await versionDetector.getCurrentVersion('stable');
        final result2 = await versionDetector.getCurrentVersion('nightly');

        // Both should return null in test environment
        expect(result1, isNull);
        expect(result2, isNull);
      });

      test('clearVersionInfo completes without error', () async {
        // Should complete without throwing even if SharedPreferences fails
        expect(
          () => versionDetector.clearVersionInfo('stable'),
          returnsNormally,
        );
      });
    });
  });
}
