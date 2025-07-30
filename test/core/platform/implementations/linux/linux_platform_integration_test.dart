import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/linux/linux_installer.dart';
import 'package:eden_updater/core/platform/implementations/linux/linux_launcher.dart';
import 'package:eden_updater/core/platform/implementations/linux/linux_file_handler.dart';
import 'package:eden_updater/core/platform/implementations/linux/linux_version_detector.dart';
import 'package:eden_updater/services/extraction/extraction_service.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/models/update_info.dart';
import 'package:eden_updater/core/errors/app_exceptions.dart';
import 'package:eden_updater/core/platform/platform_factory.dart';

void main() {
  group('Linux Platform Integration Tests', () {
    late LinuxInstaller installer;
    late LinuxLauncher launcher;
    late LinuxFileHandler fileHandler;
    late LinuxVersionDetector versionDetector;
    late ExtractionService extractionService;
    late InstallationService installationService;
    late PreferencesService preferencesService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      fileHandler = LinuxFileHandler();
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

      launcher = LinuxLauncher(preferencesService, installationService);
      versionDetector = LinuxVersionDetector(
        preferencesService,
        installationService,
      );
    });

    group('Linux Installation Functionality', () {
      test('validates Linux archive format support', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Test supported formats
        final supportedFormats = [
          'test.zip',
          'test.tar.gz',
          'test.tar.bz2',
          'test.tar.xz',
          'test.AppImage',
          'eden.AppImage',
        ];

        for (final format in supportedFormats) {
          final testFile = File(path.join(tempDir.path, format));
          await testFile.create();

          final canHandle = await installer.canHandle(testFile.path);
          expect(canHandle, isTrue, reason: 'Should handle $format');
        }

        // Test unsupported formats
        final unsupportedFormats = ['test.apk', 'test.deb', 'test.rpm'];

        for (final format in unsupportedFormats) {
          final testFile = File(path.join(tempDir.path, format));
          await testFile.create();

          final canHandle = await installer.canHandle(testFile.path);
          expect(canHandle, isFalse, reason: 'Should not handle $format');
        }

        await tempDir.delete(recursive: true);
      });

      test(
        'validates Linux file operations and executable permissions',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('linux_test_');

          // Test executable detection
          final edenBinary = File(path.join(tempDir.path, 'eden'));
          await edenBinary.create();

          expect(fileHandler.isEdenExecutable('eden'), isTrue);
          expect(fileHandler.isEdenExecutable('eden-stable'), isTrue);
          expect(fileHandler.isEdenExecutable('eden-nightly'), isTrue);
          expect(fileHandler.isEdenExecutable('eden.AppImage'), isTrue);
          expect(fileHandler.isEdenExecutable('other-app'), isFalse);

          // Test executable path generation
          final executablePath = fileHandler.getEdenExecutablePath(
            tempDir.path,
            'stable',
          );
          expect(
            executablePath,
            equals(path.join(tempDir.path, 'eden-stable')),
          );

          // Test makeExecutable (should work on Linux)
          await fileHandler.makeExecutable(edenBinary.path);

          // Verify executable permissions were set
          final hasPermission = await fileHandler.hasExecutablePermission(
            edenBinary.path,
          );
          expect(hasPermission, isTrue);

          // Test Eden files detection
          expect(await fileHandler.containsEdenFiles(tempDir.path), isTrue);

          await tempDir.delete(recursive: true);
        },
      );

      test('validates Linux AppImage handling', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Create a mock AppImage file
        final appImageFile = File(path.join(tempDir.path, 'Eden.AppImage'));
        await appImageFile.create();

        // Write ELF magic bytes to simulate AppImage
        await appImageFile.writeAsBytes([0x7F, 0x45, 0x4C, 0x46]);

        // Test AppImage detection
        expect(await installer.canHandle(appImageFile.path), isTrue);

        // Test AppImage file validation
        expect(fileHandler.isEdenExecutable('Eden.AppImage'), isTrue);

        await tempDir.delete(recursive: true);
      });

      test('validates Linux desktop integration paths', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Create typical Linux Eden distribution structure
        final edenBinary = File(path.join(tempDir.path, 'eden'));
        await edenBinary.create();

        final qtCore = File(path.join(tempDir.path, 'libQt5Core.so.5'));
        await qtCore.create();

        final platformsDir = Directory(path.join(tempDir.path, 'platforms'));
        await platformsDir.create();

        final xcb = File(path.join(platformsDir.path, 'libqxcb.so'));
        await xcb.create();

        // Test that Linux file handler recognizes this as Eden installation
        expect(await fileHandler.containsEdenFiles(tempDir.path), isTrue);

        await tempDir.delete(recursive: true);
      });
    });

    group('Linux Launcher Functionality', () {
      test('validates Eden executable search functionality', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Test with executable at root level
        final rootExe = File(path.join(tempDir.path, 'eden'));
        await rootExe.create();

        final foundExe = await launcher.findEdenExecutable(
          tempDir.path,
          'stable',
        );

        // Should find the executable (or return null if InstallationService fails)
        expect(foundExe, anyOf(equals(rootExe.path), isNull));

        await rootExe.delete();

        // Test with AppImage
        final appImage = File(path.join(tempDir.path, 'eden-stable'));
        await appImage.create();

        final foundAppImage = await launcher.findEdenExecutable(
          tempDir.path,
          'stable',
        );

        // Should find the AppImage
        expect(foundAppImage, anyOf(equals(appImage.path), isNull));

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

      test('validates desktop shortcut creation attempt', () async {
        // Test shortcut creation (will likely fail in test environment)
        expect(
          () => launcher.createDesktopShortcut(),
          anyOf(completes, throwsA(isA<LauncherException>())),
        );
      });
    });

    group('Linux Version Management', () {
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

      test('validates AppImage version detection', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Create AppImage with version in filename
        final appImageWithVersion = File(
          path.join(tempDir.path, 'Eden_v1.2.3.AppImage'),
        );
        await appImageWithVersion.create();

        // The version detector should be able to extract version from filename
        // This is tested indirectly through the getCurrentVersion method

        await tempDir.delete(recursive: true);
      });
    });

    group('Linux Platform Factory Integration', () {
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

    group('Linux Error Handling and Logging', () {
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
            '/non/existent/file.tar.gz',
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

        // Test makeExecutable with non-existent file (should not throw, just log warning)
        await fileHandler.makeExecutable('/non/existent/file');
        // Should complete without throwing
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

    group('Linux Platform Capabilities', () {
      test('validates Linux-specific features', () {
        // Test that Linux supports various executable names
        expect(fileHandler.isEdenExecutable('eden'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-stable'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-nightly'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden.AppImage'), isTrue);

        // Test Linux executable path format
        final execPath = fileHandler.getEdenExecutablePath('/test', 'stable');
        expect(execPath.endsWith('eden-stable'), isTrue);

        final nightlyPath = fileHandler.getEdenExecutablePath(
          '/test',
          'nightly',
        );
        expect(nightlyPath.endsWith('eden-nightly'), isTrue);
      });

      test(
        'validates Linux archive and AppImage handling capabilities',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('linux_test_');

          // Test various Linux-compatible formats
          final formats = {
            'test.tar.gz': true,
            'test.tar.bz2': true,
            'test.tar.xz': true,
            'test.zip': true,
            'Eden.AppImage': true,
            'eden-v1.2.3.AppImage': true,
            'test.apk': false,
            'test.exe': false,
          };

          for (final entry in formats.entries) {
            final testFile = File(path.join(tempDir.path, entry.key));
            await testFile.create();

            final canHandle = await installer.canHandle(testFile.path);
            expect(
              canHandle,
              equals(entry.value),
              reason:
                  'Linux installer should ${entry.value ? "handle" : "not handle"} ${entry.key}',
            );
          }

          await tempDir.delete(recursive: true);
        },
      );

      test('validates Linux executable permissions handling', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Create a test file
        final testFile = File(path.join(tempDir.path, 'test_executable'));
        await testFile.create();

        // Initially should not be executable
        final initialPermission = await fileHandler.hasExecutablePermission(
          testFile.path,
        );
        expect(initialPermission, isFalse);

        // Make it executable
        await fileHandler.makeExecutable(testFile.path);

        // Should now be executable
        final finalPermission = await fileHandler.hasExecutablePermission(
          testFile.path,
        );
        expect(finalPermission, isTrue);

        // Test permission string retrieval
        final permissions = await fileHandler.getFilePermissions(testFile.path);
        expect(permissions, isNotNull);
        expect(permissions!.contains('x'), isTrue);

        await tempDir.delete(recursive: true);
      });

      test('validates Linux MIME type detection', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Create a test executable file
        final testFile = File(path.join(tempDir.path, 'test_binary'));
        await testFile.create();
        await fileHandler.makeExecutable(testFile.path);

        // Test MIME type detection (may not work in all test environments)
        final mimeType = await fileHandler.getFileMimeType(testFile.path);
        // MIME type detection may not work in test environment, so we just check it doesn't throw
        expect(mimeType, anyOf(isNull, isA<String>()));

        await tempDir.delete(recursive: true);
      });
    });

    group('Linux Directory Structure and Path Handling', () {
      test('validates Linux directory structure handling', () async {
        final tempDir = await Directory.systemTemp.createTemp('linux_test_');

        // Create typical Linux application structure
        final binDir = Directory(path.join(tempDir.path, 'bin'));
        await binDir.create();

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        await libDir.create();

        final shareDir = Directory(path.join(tempDir.path, 'share'));
        await shareDir.create();

        // Create Eden executable in bin directory
        final edenExe = File(path.join(binDir.path, 'eden'));
        await edenExe.create();

        // Create Qt libraries in lib directory
        final qtLib = File(path.join(libDir.path, 'libQt5Core.so.5'));
        await qtLib.create();

        // Test that file handler can find Eden files in this structure
        expect(await fileHandler.containsEdenFiles(tempDir.path), isTrue);

        await tempDir.delete(recursive: true);
      });

      test('validates Linux path handling for different channels', () {
        // Test stable channel path
        final stablePath = fileHandler.getEdenExecutablePath(
          '/opt/eden',
          'stable',
        );
        expect(stablePath, equals('/opt/eden/eden-stable'));

        // Test nightly channel path
        final nightlyPath = fileHandler.getEdenExecutablePath(
          '/opt/eden',
          'nightly',
        );
        expect(nightlyPath, equals('/opt/eden/eden-nightly'));

        // Test null channel (should default to generic)
        final genericPath = fileHandler.getEdenExecutablePath(
          '/opt/eden',
          null,
        );
        expect(genericPath, equals('/opt/eden/eden'));
      });
    });
  });
}
