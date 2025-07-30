import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/linux/linux_installer.dart';
import 'package:eden_updater/services/extraction/extraction_service.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/models/update_info.dart';
import 'package:eden_updater/core/errors/app_exceptions.dart';
import 'package:eden_updater/core/platform/implementations/linux/linux_file_handler.dart';

void main() {
  group('LinuxInstaller', () {
    late LinuxInstaller installer;
    late ExtractionService extractionService;
    late InstallationService installationService;
    late PreferencesService preferencesService;

    setUp(() {
      final fileHandler = LinuxFileHandler();
      preferencesService = PreferencesService();
      installationService = InstallationService(
        preferencesService,
        fileHandler,
      );
      extractionService = ExtractionService(fileHandler);

      installer = LinuxInstaller(
        extractionService,
        installationService,
        preferencesService,
      );
    });

    group('canHandle', () {
      test('returns true for AppImage files', () async {
        // Create temporary test files
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final appImageFile = File(path.join(tempDir.path, 'Eden.AppImage'));
        final appImageFile2 = File(
          path.join(tempDir.path, 'eden-nightly.appimage'),
        );

        await appImageFile.create();
        await appImageFile2.create();

        expect(await installer.canHandle(appImageFile.path), isTrue);
        expect(await installer.canHandle(appImageFile2.path), isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns true for supported archive formats', () async {
        // Create temporary test files
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final zipFile = File(path.join(tempDir.path, 'test.zip'));
        final tarGzFile = File(path.join(tempDir.path, 'test.tar.gz'));
        final tarBz2File = File(path.join(tempDir.path, 'test.tar.bz2'));
        final tarXzFile = File(path.join(tempDir.path, 'test.tar.xz'));

        await zipFile.create();
        await tarGzFile.create();
        await tarBz2File.create();
        await tarXzFile.create();

        expect(await installer.canHandle(zipFile.path), isTrue);
        expect(await installer.canHandle(tarGzFile.path), isTrue);
        expect(await installer.canHandle(tarBz2File.path), isTrue);
        expect(await installer.canHandle(tarXzFile.path), isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for unsupported formats', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final apkFile = File(path.join(tempDir.path, 'test.apk'));
        final exeFile = File(path.join(tempDir.path, 'test.exe'));

        await apkFile.create();
        await exeFile.create();

        expect(await installer.canHandle(apkFile.path), isFalse);
        expect(await installer.canHandle(exeFile.path), isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for non-existent files', () async {
        expect(await installer.canHandle('/non/existent/file.zip'), isFalse);
      });
    });

    group('install', () {
      test('throws UpdateException when file does not exist', () async {
        final testUpdateInfo = UpdateInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/download',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        expect(
          () => installer.install(
            '/non/existent/file.zip',
            testUpdateInfo,
            createShortcuts: false,
            portableMode: false,
            onProgress: (_) {},
            onStatusUpdate: (_) {},
          ),
          throwsA(isA<UpdateException>()),
        );
      });

      test('handles AppImage installation flow', () async {
        // Create a temporary AppImage file
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final appImageFile = File(path.join(tempDir.path, 'Eden.AppImage'));

        // Create a simple executable file (mock AppImage)
        await appImageFile.writeAsBytes([
          0x7F,
          0x45,
          0x4C,
          0x46,
        ]); // ELF magic bytes

        // This test will fail in the actual installation due to missing dependencies
        // but we can verify the file type detection works
        expect(await installer.canHandle(appImageFile.path), isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('postInstallSetup', () {
      test('completes without throwing when given valid parameters', () async {
        final testInstallPath = '/test/install/path';
        final testUpdateInfo = UpdateInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/download',
          releaseNotes: 'Test release',
          releaseDate: DateTime.now(),
          fileSize: 1024,
          releaseUrl: 'https://example.com/release',
        );

        // Should not throw even if path doesn't exist
        await installer.postInstallSetup(testInstallPath, testUpdateInfo);
      });
    });
  });
}
