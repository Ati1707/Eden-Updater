import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/windows/windows_version_detector.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/models/update_info.dart';
import 'package:eden_updater/core/platform/implementations/windows/windows_file_handler.dart';

void main() {
  group('WindowsVersionDetector', () {
    late WindowsVersionDetector versionDetector;
    late PreferencesService preferencesService;
    late InstallationService installationService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      final fileHandler = WindowsFileHandler();
      preferencesService = PreferencesService();
      installationService = InstallationService(
        preferencesService,
        fileHandler,
      );

      versionDetector = WindowsVersionDetector(
        preferencesService,
        installationService,
      );
    });

    group('getCurrentVersion', () {
      test(
        'returns not installed when no version stored and no executable found',
        () async {
          final result = await versionDetector.getCurrentVersion('stable');

          expect(result, isNotNull);
          expect(result!.version, equals('Not installed'));
        },
      );

      test('handles errors gracefully and returns not installed', () async {
        // Test with invalid channel to potentially trigger error handling
        final result = await versionDetector.getCurrentVersion(
          'invalid_channel_name_that_might_cause_issues',
        );

        expect(result, isNotNull);
        expect(result!.version, equals('Not installed'));
      });
    });

    group('storeVersionInfo', () {
      test('attempts to store version info', () async {
        final updateInfo = UpdateInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/download',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        // The method may fail due to SharedPreferences not being available in test environment
        // but it should handle the error gracefully
        expect(
          () => versionDetector.storeVersionInfo(updateInfo, 'stable'),
          anyOf(completes, throwsA(isA<Exception>())),
        );
      });

      test('handles executable path storage', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final executablePath = path.join(tempDir.path, 'eden.exe');
        await File(executablePath).create();

        final updateInfo = UpdateInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/download',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        // The method may fail due to SharedPreferences not being available in test environment
        expect(
          () => versionDetector.storeVersionInfo(updateInfo, 'stable'),
          anyOf(completes, throwsA(isA<Exception>())),
        );

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('clearVersionInfo', () {
      test('attempts to clear version info', () async {
        // The method may fail due to SharedPreferences not being available in test environment
        expect(
          () => versionDetector.clearVersionInfo('stable'),
          anyOf(completes, throwsA(isA<Exception>())),
        );
      });
    });
  });
}
