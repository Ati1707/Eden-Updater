import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/windows/windows_file_handler.dart';

void main() {
  group('WindowsFileHandler', () {
    late WindowsFileHandler fileHandler;

    setUp(() {
      fileHandler = WindowsFileHandler();
    });

    group('isEdenExecutable', () {
      test('returns true for eden.exe', () {
        expect(fileHandler.isEdenExecutable('eden.exe'), isTrue);
        expect(fileHandler.isEdenExecutable('EDEN.EXE'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden.exe'), isTrue);
      });

      test('returns false for other executables', () {
        expect(fileHandler.isEdenExecutable('eden-cmd.exe'), isFalse);
        expect(fileHandler.isEdenExecutable('eden-cli.exe'), isFalse);
        expect(fileHandler.isEdenExecutable('other.exe'), isFalse);
        expect(fileHandler.isEdenExecutable('eden'), isFalse);
        expect(fileHandler.isEdenExecutable('eden.AppImage'), isFalse);
      });
    });

    group('getEdenExecutablePath', () {
      test('returns correct path for any channel', () {
        final installPath = '/test/install/path';

        expect(
          fileHandler.getEdenExecutablePath(installPath, 'stable'),
          equals(path.join(installPath, 'eden.exe')),
        );

        expect(
          fileHandler.getEdenExecutablePath(installPath, 'nightly'),
          equals(path.join(installPath, 'eden.exe')),
        );

        expect(
          fileHandler.getEdenExecutablePath(installPath, null),
          equals(path.join(installPath, 'eden.exe')),
        );
      });
    });

    group('makeExecutable', () {
      test('completes without error for existing .exe file', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final exeFile = File(path.join(tempDir.path, 'test.exe'));
        await exeFile.create();

        // Should not throw
        await fileHandler.makeExecutable(exeFile.path);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('handles non-existent file gracefully', () async {
        // Should not throw
        await fileHandler.makeExecutable('/non/existent/file.exe');
      });

      test('handles non-exe file gracefully', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final txtFile = File(path.join(tempDir.path, 'test.txt'));
        await txtFile.create();

        // Should not throw
        await fileHandler.makeExecutable(txtFile.path);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('containsEdenFiles', () {
      test('returns true when eden.exe is present', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final edenExe = File(path.join(tempDir.path, 'eden.exe'));
        await edenExe.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns true when Qt DLLs are present', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final qtDll = File(path.join(tempDir.path, 'qt5core.dll'));
        await qtDll.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns true when Eden-related files are present', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final edenDll = File(path.join(tempDir.path, 'eden-platforms.dll'));
        await edenDll.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false when no Eden files are present', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final randomFile = File(path.join(tempDir.path, 'random.txt'));
        await randomFile.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for non-existent directory', () async {
        final result = await fileHandler.containsEdenFiles(
          '/non/existent/path',
        );

        expect(result, isFalse);
      });

      test('searches recursively in subdirectories', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final subDir = Directory(path.join(tempDir.path, 'subdir'));
        await subDir.create();
        final edenExe = File(path.join(subDir.path, 'eden.exe'));
        await edenExe.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });
  });
}
