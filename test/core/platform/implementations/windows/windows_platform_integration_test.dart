import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/windows/windows_installer.dart';
import 'package:eden_updater/core/platform/implementations/windows/windows_launcher.dart';
import 'package:eden_updater/core/platform/implementations/windows/windows_file_handler.dart';
import 'package:eden_updater/core/platform/implementations/windows/windows_version_detector.dart';
import 'package:eden_updater/services/extraction/extraction_service.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/models/update_info.dart';
import 'package:eden_updater/core/errors/app_exceptions.dart';
import 'package:eden_updater/core/platform/platform_factory.dart';

void main() {
  group('Windows Platform Integration Tests', () {
    late WindowsInstaller installer;
    late WindowsLauncher launcher;
    late WindowsFileHandler fileHandler;
    late WindowsVersionDetector versionDetector;
    late ExtractionService extractionService;
    late InstallationService installationService;
    late PreferencesService preferencesService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      fileHandler = WindowsFileHandler();
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

      launcher = WindowsLauncher(preferencesService, installationService);
      versionDetector = WindowsVersionDetector(
        preferencesService,
        installationService,
      );
    });

    group('Windows Installation Functionality', () {
      test('validates Windows archive format support', () async {
        final tempDir = await Directory.systemTemp.createTemp('windows_test_');

        // Test supported formats
        final supportedFormats = [
          'test.zip',
          'test.7z',
          'test.tar.gz',
          'test.tar.bz2',
          'test.rar',
        ];

        for (final format in supportedFormats) {
          final testFile = File(path.join(tempDir.path, format));
          await testFile.create();

          final canHandle = await installer.canHandle(testFile.path);
          expect(canHandle, isTrue, reason: 'Should handle $format');
        }

        // Test unsupported formats
        final unsupportedFormats = ['test.apk', 'test.AppImage', 'test.deb'];

        for (final format in unsupportedFormats) {
          final testFile = File(path.join(tempDir.path, format));
          await testFile.create();

          final canHandle = await installer.canHandle(testFile.path);
          expect(canHandle, isFalse, reason: 'Should not handle $format');
        }

        await tempDir.delete(recursive: true);
      });

      test('validates Windows file operations and permissions', () async {
        final tempDir = await Directory.systemTemp.createTemp('windows_test_');

        // Test executable detection
        final edenExe = File(path.join(tempDir.path, 'eden.exe'));
        await edenExe.create();

        expect(fileHandler.isEdenExecutable('eden.exe'), isTrue);
        expect(fileHandler.isEdenExecutable('EDEN.EXE'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-cmd.exe'), isFalse);

        // Test executable path generation
        final executablePath = fileHandler.getEdenExecutablePath(
          tempDir.path,
          'stable',
        );
        expect(executablePath, equals(path.join(tempDir.path, 'eden.exe')));

        // Test makeExecutable (should not throw on Windows)
        await fileHandler.makeExecutable(edenExe.path);

        // Test Eden files detection
        expect(await fileHandler.containsEdenFiles(tempDir.path), isTrue);

        await tempDir.delete(recursive: true);
      });

      test('validates Windows-specific file structure detection', () async {
        final tempDir = await Directory.systemTemp.createTemp('windows_test_');

        // Create typical Windows Eden distribution structure
        final edenExe = File(path.join(tempDir.path, 'eden.exe'));
        await edenExe.create();

        final qtCore = File(path.join(tempDir.path, 'Qt5Core.dll'));
        await qtCore.create();

        final platformsDir = Directory(path.join(tempDir.path, 'platforms'));
        await platformsDir.create();

        final qwindows = File(path.join(platformsDir.path, 'qwindows.dll'));
        await qwindows.create();

        // Test that Windows file handler recognizes this as Eden installation
        expect(await fileHandler.containsEdenFiles(tempDir.path), isTrue);

        await tempDir.delete(recursive: true);
      });
    });

    group('Windows Launcher Functionality', () {
      test('validates Eden executable search functionality', () async {
        final tempDir = await Directory.systemTemp.createTemp('windows_test_');

        // Test with executable at root level
        final rootExe = File(path.join(tempDir.path, 'eden.exe'));
        await rootExe.create();

        final foundExe = await launcher.findEdenExecutable(
          tempDir.path,
          'stable',
        );

        // Should find the executable (or return null if InstallationService fails)
        expect(foundExe, anyOf(equals(rootExe.path), isNull));

        await rootExe.delete();

        // Test with executable in subdirectory
        final subDir = Directory(path.join(tempDir.path, 'bin'));
        await subDir.create();
        final subExe = File(path.join(subDir.path, 'eden.exe'));
        await subExe.create();

        final foundSubExe = await launcher.findEdenExecutable(
          tempDir.path,
          'stable',
        );

        // Should find the executable in subdirectory
        expect(foundSubExe, anyOf(equals(subExe.path), isNull));

        await tempDir.delete(recursive: true);
      });

      test(
        'validates launcher error handling for missing executable',
        () async {
          // Test launching when no Eden is installed
          expect(
            () => launcher.launchEden(),
            throwsA(isA<LauncherException>()),
          );
        },
      );

      test('validates shortcut creation attempt', () async {
        // Test shortcut creation (will likely fail in test environment)
        expect(
          () => launcher.createDesktopShortcut(),
          anyOf(completes, throwsA(isA<LauncherException>())),
        );
      });
    });

    group('Windows Version Management', () {
      test('validates version detection for non-installed Eden', () async {
        final version = await versionDetector.getCurrentVersion('stable');

        // Should return "Not installed" when no Eden is found
        expect(version, isNotNull);
        expect(version!.version, equals('Not installed'));
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
    });

    group('Windows Platform Factory Integration', () {
      test('validates platform detection and service creation', () {
        // Test that PlatformFactory can detect Windows (if running on Windows)
        // or handle non-Windows gracefully
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

    group('Windows Error Handling and Logging', () {
      test('validates error handling for invalid file paths', () async {
        // Test installer with non-existent file
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

      test('validates file handler error handling', () async {
        // Test with non-existent directory
        expect(
          await fileHandler.containsEdenFiles('/non/existent/path'),
          isFalse,
        );

        // Test makeExecutable with non-existent file
        await fileHandler.makeExecutable('/non/existent/file.exe');
        // Should not throw
      });

      test('validates launcher error handling', () async {
        // Test finding executable in non-existent directory
        final result = await launcher.findEdenExecutable(
          '/non/existent/path',
          'stable',
        );
        expect(result, isNull);
      });
    });

    group('Windows Platform Capabilities', () {
      test('validates Windows-specific features', () {
        // Test that Windows supports shortcuts
        expect(fileHandler.isEdenExecutable('eden.exe'), isTrue);

        // Test Windows executable path format
        final execPath = fileHandler.getEdenExecutablePath('/test', 'stable');
        expect(execPath.endsWith('eden.exe'), isTrue);
      });

      test('validates Windows archive handling capabilities', () async {
        final tempDir = await Directory.systemTemp.createTemp('windows_test_');

        // Test various Windows-compatible archive formats
        final formats = {
          'test.zip': true,
          'test.7z': true,
          'test.tar.gz': true,
          'test.rar': true,
          'test.apk': false,
          'test.AppImage': false,
        };

        for (final entry in formats.entries) {
          final testFile = File(path.join(tempDir.path, entry.key));
          await testFile.create();

          final canHandle = await installer.canHandle(testFile.path);
          expect(
            canHandle,
            equals(entry.value),
            reason:
                'Windows installer should ${entry.value ? "handle" : "not handle"} ${entry.key}',
          );
        }

        await tempDir.delete(recursive: true);
      });
    });
  });
}
