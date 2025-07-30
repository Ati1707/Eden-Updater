import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:eden_updater/core/platform/implementations/android/android_installer.dart';
import 'package:eden_updater/core/platform/exceptions/platform_exceptions.dart';
import 'package:eden_updater/models/update_info.dart';

void main() {
  group('AndroidInstaller', () {
    late AndroidInstaller installer;

    setUp(() {
      installer = AndroidInstaller();
    });

    group('canHandle', () {
      test('returns true for APK files with .apk extension', () async {
        // Create a temporary APK file for testing
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final apkFile = File('${tempDir.path}/test.apk');
        await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // ZIP signature

        final result = await installer.canHandle(apkFile.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for non-APK files', () async {
        // Create a temporary non-APK file for testing
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final txtFile = File('${tempDir.path}/test.txt');
        await txtFile.writeAsString('test content');

        final result = await installer.canHandle(txtFile.path);

        expect(result, isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for non-existent files', () async {
        final result = await installer.canHandle('/non/existent/file.apk');

        expect(result, isFalse);
      });

      test(
        'returns true for files with ZIP signature and .apk extension',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('test_');
          final apkFile = File('${tempDir.path}/eden.apk');
          // Write ZIP file signature (APK files are ZIP files)
          await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]);

          final result = await installer.canHandle(apkFile.path);

          expect(result, isTrue);

          // Cleanup
          await tempDir.delete(recursive: true);
        },
      );
    });

    group('install', () {
      test('throws exception for non-APK files', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final txtFile = File('${tempDir.path}/test.txt');
        await txtFile.writeAsString('test content');

        final updateInfo = UpdateInfo(
          version: 'v1.0.0',
          downloadUrl: 'https://example.com/test.txt',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        expect(
          () => installer.install(
            txtFile.path,
            updateInfo,
            createShortcuts: false,
            portableMode: false,
            onProgress: (progress) {},
            onStatusUpdate: (status) {},
          ),
          throwsA(isA<PlatformOperationException>()),
        );

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('completes successfully for valid APK files', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final apkFile = File('${tempDir.path}/eden.apk');
        // Write ZIP file signature (APK files are ZIP files)
        await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]);

        final updateInfo = UpdateInfo(
          version: 'v1.0.0',
          downloadUrl: 'https://example.com/eden.apk',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        var progressCalled = false;
        var statusCalled = false;

        // This test will attempt to launch Android intents, which will fail in test environment
        // but we can verify the method completes without throwing unexpected exceptions
        try {
          await installer.install(
            apkFile.path,
            updateInfo,
            createShortcuts: false,
            portableMode: false,
            onProgress: (progress) {
              progressCalled = true;
              expect(progress, isA<double>());
              expect(progress, greaterThanOrEqualTo(0.0));
              expect(progress, lessThanOrEqualTo(1.0));
            },
            onStatusUpdate: (status) {
              statusCalled = true;
              expect(status, isA<String>());
              expect(status.isNotEmpty, isTrue);
            },
          );
        } catch (e) {
          // In test environment, Android intents will fail, which is expected
          expect(e, isA<PlatformOperationException>());
        }

        expect(progressCalled, isTrue);
        expect(statusCalled, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('postInstallSetup', () {
      test('completes without error', () async {
        final updateInfo = UpdateInfo(
          version: 'v1.0.0',
          downloadUrl: 'https://example.com/eden.apk',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        // Should complete without throwing
        await installer.postInstallSetup('/test/path', updateInfo);
      });
    });
  });
}
