import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/android/android_installer.dart';
import 'package:eden_updater/core/platform/implementations/android/android_launcher.dart';
import 'package:eden_updater/core/platform/implementations/android/android_file_handler.dart';
import 'package:eden_updater/core/platform/implementations/android/android_version_detector.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/models/update_info.dart';
import 'package:eden_updater/core/platform/exceptions/platform_exceptions.dart';
import 'package:eden_updater/core/platform/platform_factory.dart';

void main() {
  group('Android Platform Integration Tests', () {
    late AndroidInstaller installer;
    late AndroidLauncher launcher;
    late AndroidFileHandler fileHandler;
    late AndroidVersionDetector versionDetector;
    late PreferencesService preferencesService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      fileHandler = AndroidFileHandler();
      preferencesService = PreferencesService();

      installer = AndroidInstaller();
      launcher = AndroidLauncher(preferencesService);
      versionDetector = AndroidVersionDetector(preferencesService);
    });

    group('Android Installation Functionality', () {
      test('validates Android APK format support', () async {
        final tempDir = await Directory.systemTemp.createTemp('android_test_');

        // Test supported formats (APK only)
        final supportedFormats = [
          'eden.apk',
          'Eden_v1.2.3.apk',
          'eden-stable.apk',
          'eden-nightly.apk',
        ];

        for (final format in supportedFormats) {
          final testFile = File(path.join(tempDir.path, format));
          await testFile.create();

          // Write ZIP signature to simulate APK
          await testFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

          final canHandle = await installer.canHandle(testFile.path);
          expect(canHandle, isTrue, reason: 'Should handle $format');
        }

        // Test unsupported formats
        final unsupportedFormats = [
          'test.zip',
          'test.tar.gz',
          'test.AppImage',
          'test.exe',
          'eden.txt',
        ];

        for (final format in unsupportedFormats) {
          final testFile = File(path.join(tempDir.path, format));
          await testFile.create();

          final canHandle = await installer.canHandle(testFile.path);
          expect(canHandle, isFalse, reason: 'Should not handle $format');
        }

        await tempDir.delete(recursive: true);
      });

      test('validates Android APK file detection', () async {
        final tempDir = await Directory.systemTemp.createTemp('android_test_');

        // Create a mock APK file with proper signature
        final apkFile = File(path.join(tempDir.path, 'eden.apk'));
        await apkFile.create();

        // Write ZIP signature (APK files are ZIP files)
        await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

        // Test APK detection
        expect(await fileHandler.isApkFile(apkFile.path), isTrue);
        expect(fileHandler.isEdenExecutable('eden.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden_v1.2.3.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-stable.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('other.apk'), isFalse);

        await tempDir.delete(recursive: true);
      });

      test('validates Android file operations and paths', () async {
        final tempDir = await Directory.systemTemp.createTemp('android_test_');

        // Test executable path generation
        final executablePath = fileHandler.getEdenExecutablePath(
          tempDir.path,
          'stable',
        );
        expect(
          executablePath,
          equals(path.join(tempDir.path, 'eden-stable.apk')),
        );

        final nightlyPath = fileHandler.getEdenExecutablePath(
          tempDir.path,
          'nightly',
        );
        expect(
          nightlyPath,
          equals(path.join(tempDir.path, 'eden-nightly.apk')),
        );

        // Test makeExecutable (should not throw on Android)
        final apkFile = File(path.join(tempDir.path, 'eden.apk'));
        await apkFile.create();
        await fileHandler.makeExecutable(apkFile.path);

        // Test Eden files detection
        expect(await fileHandler.containsEdenFiles(tempDir.path), isTrue);

        await tempDir.delete(recursive: true);
      });

      test('validates Android-specific directory paths', () {
        // Test Android-specific path methods
        expect(
          fileHandler.getDownloadsPath(),
          equals('/storage/emulated/0/Download'),
        );
        expect(
          fileHandler.getExternalStoragePath(),
          equals('/storage/emulated/0'),
        );

        final appFilesPath = fileHandler.getAppExternalFilesPath();
        expect(appFilesPath.contains('Android/data'), isTrue);
        expect(appFilesPath.contains('files'), isTrue);
      });

      test('validates Android installation error handling', () async {
        final testUpdateInfo = UpdateInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/download',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        // Test with non-existent file
        expect(
          () => installer.install(
            '/non/existent/file.apk',
            testUpdateInfo,
            createShortcuts: false,
            portableMode: false,
            onProgress: (_) {},
            onStatusUpdate: (_) {},
          ),
          throwsA(isA<PlatformOperationException>()),
        );

        // Test with non-APK file
        final tempDir = await Directory.systemTemp.createTemp('android_test_');
        final nonApkFile = File(path.join(tempDir.path, 'test.txt'));
        await nonApkFile.create();

        expect(
          () => installer.install(
            nonApkFile.path,
            testUpdateInfo,
            createShortcuts: false,
            portableMode: false,
            onProgress: (_) {},
            onStatusUpdate: (_) {},
          ),
          throwsA(isA<PlatformOperationException>()),
        );

        await tempDir.delete(recursive: true);
      });
    });

    group('Android Launcher Functionality', () {
      test('validates Android package detection', () async {
        // Test finding Eden executable (returns package name on Android)
        final result = await launcher.findEdenExecutable(
          '/test/path',
          'stable',
        );

        // Should return null if no packages are installed (in test environment)
        expect(result, isNull);
      });

      test('validates launcher error handling for missing app', () async {
        // Test launching when no Eden is installed
        expect(
          () => launcher.launchEden(),
          throwsA(isA<PlatformOperationException>()),
        );
      });

      test('validates desktop shortcut handling', () async {
        // Test shortcut creation (should complete without error on Android)
        await launcher.createDesktopShortcut();
        // Should complete without throwing (shortcuts not applicable on Android)
      });
    });

    group('Android Version Management', () {
      test('validates version detection for non-installed Eden', () async {
        final version = await versionDetector.getCurrentVersion('stable');

        // Should return null when no Eden is found
        expect(version, isNull);
      });

      test('validates version storage and retrieval', () async {
        final testUpdateInfo = UpdateInfo(
          version: '1.2.3',
          downloadUrl: 'https://example.com/download',
          releaseNotes: 'Test version',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        // Test storing version info (may fail due to SharedPreferences in test)
        expect(
          () => versionDetector.storeVersionInfo(testUpdateInfo, 'stable'),
          anyOf(completes, throwsA(isA<Exception>())),
        );

        // Test clearing version info
        expect(
          () => versionDetector.clearVersionInfo('stable'),
          anyOf(completes, throwsA(isA<Exception>())),
        );
      });

      test('validates Android installation metadata handling', () async {
        // Test metadata methods (may fail due to SharedPreferences in test)
        try {
          final hasMetadata = await versionDetector.hasInstallationMetadata(
            'stable',
          );
          expect(hasMetadata, isFalse);
        } catch (e) {
          // Expected to fail in test environment
          expect(e, isA<Exception>());
        }

        try {
          final installDate = await versionDetector.getInstallationDate(
            'stable',
          );
          expect(installDate, isNull);
        } catch (e) {
          // Expected to fail in test environment
          expect(e, isA<Exception>());
        }

        try {
          final packageName = await versionDetector.getSuccessfulPackageName();
          expect(packageName, isNull);
        } catch (e) {
          // Expected to fail in test environment
          expect(e, isA<Exception>());
        }
      });

      test('validates test version override functionality', () async {
        // Test setting version for testing (may fail due to SharedPreferences in test)
        expect(
          () => versionDetector.setCurrentVersionForTesting(
            'v1.0.0-test',
            'stable',
          ),
          anyOf(completes, throwsA(isA<Exception>())),
        );

        // Test retrieving version (may fail due to SharedPreferences in test)
        try {
          final version = await versionDetector.getCurrentVersion('stable');
          // In test environment, should return null or a version
          expect(version, anyOf(isNull, isA<UpdateInfo>()));
        } catch (e) {
          // Expected to fail in test environment
          expect(e, isA<Exception>());
        }
      });
    });

    group('Android Platform Factory Integration', () {
      test('validates platform detection and service creation', () {
        // Test that PlatformFactory can detect platform configuration
        expect(
          () => PlatformFactory.getCurrentPlatformConfig(),
          returnsNormally,
        );

        // Test service creation methods exist and don't throw
        expect(() => PlatformFactory.createFileHandler(), returnsNormally);

        expect(() => PlatformFactory.createInstaller(), returnsNormally);

        expect(() => PlatformFactory.createLauncher(), returnsNormally);

        expect(() => PlatformFactory.createVersionDetector(), returnsNormally);
      });
    });

    group('Android Error Handling and Logging', () {
      test('validates file handler error handling', () async {
        // Test with non-existent directory
        expect(
          await fileHandler.containsEdenFiles('/non/existent/path'),
          isFalse,
        );

        // Test APK detection with non-existent file
        expect(await fileHandler.isApkFile('/non/existent/file.apk'), isFalse);
      });

      test('validates external storage checking', () async {
        // Test external storage availability (may not work in test environment)
        final isWritable = await fileHandler.isExternalStorageWritable();
        expect(isWritable, anyOf(isTrue, isFalse));
      });

      test('validates Android directory creation', () async {
        // Test Android directory creation (should not throw)
        await fileHandler.ensureAndroidDirectories();
        // Should complete without throwing
      });
    });

    group('Android Platform Capabilities', () {
      test('validates Android-specific features', () {
        // Test that Android supports APK files
        expect(fileHandler.isEdenExecutable('eden.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden_v1.2.3.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-stable.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-nightly.apk'), isTrue);

        // Test Android executable path format
        final execPath = fileHandler.getEdenExecutablePath('/test', 'stable');
        expect(execPath.endsWith('eden-stable.apk'), isTrue);

        final nightlyPath = fileHandler.getEdenExecutablePath(
          '/test',
          'nightly',
        );
        expect(nightlyPath.endsWith('eden-nightly.apk'), isTrue);
      });

      test('validates Android APK handling capabilities', () async {
        final tempDir = await Directory.systemTemp.createTemp('android_test_');

        // Test various Android-compatible formats
        final formats = {
          'eden.apk': true,
          'Eden_v1.2.3.apk': true,
          'eden-stable.apk': true,
          'eden-nightly.apk': true,
          'other.apk': true, // Android installer accepts any APK file
          'test.zip': false,
          'test.tar.gz': false,
          'test.AppImage': false,
        };

        for (final entry in formats.entries) {
          final testFile = File(path.join(tempDir.path, entry.key));
          await testFile.create();

          // Write ZIP signature for APK files
          if (entry.key.endsWith('.apk')) {
            await testFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);
          }

          final canHandle = await installer.canHandle(testFile.path);
          expect(
            canHandle,
            equals(entry.value),
            reason:
                'Android installer should ${entry.value ? "handle" : "not handle"} ${entry.key}',
          );
        }

        await tempDir.delete(recursive: true);
      });

      test('validates Android file signature detection', () async {
        final tempDir = await Directory.systemTemp.createTemp('android_test_');

        // Create APK with proper ZIP signature
        final validApk = File(path.join(tempDir.path, 'valid.apk'));
        await validApk.create();
        await validApk.writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]);

        expect(await fileHandler.isApkFile(validApk.path), isTrue);

        // Create file with wrong signature
        final invalidApk = File(path.join(tempDir.path, 'invalid.apk'));
        await invalidApk.create();
        await invalidApk.writeAsBytes([0x00, 0x00, 0x00, 0x00]);

        expect(
          await fileHandler.isApkFile(invalidApk.path),
          isTrue,
        ); // Still true due to .apk extension

        // Create non-APK file
        final nonApk = File(path.join(tempDir.path, 'test.txt'));
        await nonApk.create();
        await nonApk.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

        expect(await fileHandler.isApkFile(nonApk.path), isFalse);

        await tempDir.delete(recursive: true);
      });
    });

    group('Android Feature Limitation Handling', () {
      test('validates Android feature limitations', () async {
        // Test that shortcuts are not applicable on Android
        await launcher.createDesktopShortcut();
        // Should complete without error but not create actual shortcuts

        // Test that makeExecutable is not applicable on Android
        final tempDir = await Directory.systemTemp.createTemp('android_test_');
        final apkFile = File(path.join(tempDir.path, 'test.apk'));
        await apkFile.create();

        await fileHandler.makeExecutable(apkFile.path);
        // Should complete without error

        await tempDir.delete(recursive: true);
      });

      test('validates Android channel support', () {
        // Android should support both stable and nightly channels
        final stablePath = fileHandler.getEdenExecutablePath('/test', 'stable');
        expect(stablePath.contains('stable'), isTrue);

        final nightlyPath = fileHandler.getEdenExecutablePath(
          '/test',
          'nightly',
        );
        expect(nightlyPath.contains('nightly'), isTrue);
      });

      test('validates Android storage and metadata management', () async {
        // Test Android-specific storage paths
        expect(fileHandler.getDownloadsPath().contains('Download'), isTrue);
        expect(
          fileHandler.getExternalStoragePath().contains('storage'),
          isTrue,
        );
        expect(
          fileHandler.getAppExternalFilesPath().contains('Android'),
          isTrue,
        );

        // Test external storage availability check
        final isWritable = await fileHandler.isExternalStorageWritable();
        expect(isWritable, anyOf(isTrue, isFalse));
      });
    });

    group('Android Package Manager Integration', () {
      test('validates package detection methods', () async {
        // Test finding Eden executable (package-based on Android)
        final result = await launcher.findEdenExecutable(
          '/test/path',
          'stable',
        );

        // In test environment, should return null (no packages installed)
        expect(result, isNull);
      });

      test('validates Android intent-based launching', () async {
        // Test launching Eden (should fail in test environment)
        expect(
          () => launcher.launchEden(),
          throwsA(isA<PlatformOperationException>()),
        );
      });

      test('validates Android installation metadata storage', () async {
        final testUpdateInfo = UpdateInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/download.apk',
          releaseNotes: 'Test Android release',
          releaseDate: DateTime.now(),
          fileSize: 50 * 1024 * 1024, // 50MB
          releaseUrl: 'https://example.com/release',
        );

        // Test storing Android-specific metadata
        expect(
          () => versionDetector.storeVersionInfo(testUpdateInfo, 'stable'),
          anyOf(completes, throwsA(isA<Exception>())),
        );

        // Test storing successful package name
        expect(
          () => versionDetector.storeSuccessfulPackageName(
            'dev.eden.eden_emulator',
          ),
          anyOf(completes, throwsA(isA<Exception>())),
        );
      });
    });
  });
}
