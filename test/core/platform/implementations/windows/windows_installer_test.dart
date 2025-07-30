import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/windows/windows_installer.dart';
import 'package:eden_updater/services/extraction/extraction_service.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/models/update_info.dart';
import 'package:eden_updater/core/errors/app_exceptions.dart';
import 'package:eden_updater/core/platform/implementations/windows/windows_file_handler.dart';

void main() {
  group('WindowsInstaller', () {
    late WindowsInstaller installer;
    late ExtractionService extractionService;
    late InstallationService installationService;
    late PreferencesService preferencesService;

    setUp(() {
      final fileHandler = WindowsFileHandler();
      preferencesService = PreferencesService();
      installationService = InstallationService(
        preferencesService,
        fileHandler,
      );
      extractionService = ExtractionService(fileHandler);

      installer = WindowsInstaller(
        extractionService,
        installationService,
        preferencesService,
      );
    });

    group('canHandle', () {
      test('returns true for supported archive formats', () async {
        // Create temporary test files
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final zipFile = File(path.join(tempDir.path, 'test.zip'));
        final sevenZipFile = File(path.join(tempDir.path, 'test.7z'));
        final tarGzFile = File(path.join(tempDir.path, 'test.tar.gz'));

        await zipFile.create();
        await sevenZipFile.create();
        await tarGzFile.create();

        expect(await installer.canHandle(zipFile.path), isTrue);
        expect(await installer.canHandle(sevenZipFile.path), isTrue);
        expect(await installer.canHandle(tarGzFile.path), isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for unsupported formats', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final apkFile = File(path.join(tempDir.path, 'test.apk'));
        final appImageFile = File(path.join(tempDir.path, 'test.AppImage'));

        await apkFile.create();
        await appImageFile.create();

        expect(await installer.canHandle(apkFile.path), isFalse);
        expect(await installer.canHandle(appImageFile.path), isFalse);

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
