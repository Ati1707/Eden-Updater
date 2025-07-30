import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/linux/linux_file_handler.dart';

void main() {
  group('LinuxFileHandler', () {
    late LinuxFileHandler fileHandler;

    setUp(() {
      fileHandler = LinuxFileHandler();
    });

    group('isEdenExecutable', () {
      test('returns true for exact Eden executable names', () {
        expect(fileHandler.isEdenExecutable('eden'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-stable'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-nightly'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden'), isTrue);
        expect(fileHandler.isEdenExecutable('EDEN'), isTrue);
      });

      test('returns true for Eden-containing names without extensions', () {
        expect(fileHandler.isEdenExecutable('eden-emulator'), isTrue);
        expect(fileHandler.isEdenExecutable('myeden'), isTrue);
      });

      test('returns true for Eden AppImage files', () {
        expect(fileHandler.isEdenExecutable('Eden.AppImage'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-nightly.appimage'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden_v1.0.AppImage'), isTrue);
      });

      test('returns false for non-Eden files', () {
        expect(fileHandler.isEdenExecutable('emulator'), isFalse);
        expect(fileHandler.isEdenExecutable('eden.txt'), isFalse);
        expect(fileHandler.isEdenExecutable('eden.log'), isFalse);
        expect(fileHandler.isEdenExecutable('config.ini'), isFalse);
        expect(fileHandler.isEdenExecutable('application'), isFalse);
      });
    });

    group('getEdenExecutablePath', () {
      test('returns channel-specific path when channel provided', () {
        final stablePath = fileHandler.getEdenExecutablePath(
          '/test/path',
          'stable',
        );
        expect(stablePath, equals('/test/path/eden-stable'));

        final nightlyPath = fileHandler.getEdenExecutablePath(
          '/test/path',
          'nightly',
        );
        expect(nightlyPath, equals('/test/path/eden-nightly'));
      });

      test('returns generic path when no channel provided', () {
        final genericPath = fileHandler.getEdenExecutablePath(
          '/test/path',
          null,
        );
        expect(genericPath, equals('/test/path/eden'));
      });
    });

    group('containsEdenFiles', () {
      test('returns false when directory does not exist', () async {
        final result = await fileHandler.containsEdenFiles(
          '/non/existent/path',
        );
        expect(result, isFalse);
      });

      test('returns true when Eden executable is present', () async {
        // Create a temporary directory with Eden executable
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final edenFile = File(path.join(tempDir.path, 'eden'));
        await edenFile.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);
        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns true when Eden-related files are present', () async {
        // Create a temporary directory with Eden-related files
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final qtFile = File(path.join(tempDir.path, 'libqt5core.so'));
        await qtFile.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);
        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false when no Eden files are present', () async {
        // Create a temporary directory with non-Eden files
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final randomFile = File(path.join(tempDir.path, 'random.txt'));
        await randomFile.create();

        final result = await fileHandler.containsEdenFiles(tempDir.path);
        expect(result, isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('makeExecutable', () {
      test('completes without error for existing file', () async {
        // Create a temporary file
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final testFile = File(path.join(tempDir.path, 'test_executable'));
        await testFile.create();

        // This should not throw on Linux systems with chmod available
        await fileHandler.makeExecutable(testFile.path);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('logs warning for non-existent file', () async {
        // This should not throw but will log a warning
        await fileHandler.makeExecutable('/non/existent/file');
      });
    });

    group('hasExecutablePermission', () {
      test('returns false for non-existent file', () async {
        final result = await fileHandler.hasExecutablePermission(
          '/non/existent/file',
        );
        expect(result, isFalse);
      });
    });

    group('getFileMimeType', () {
      test('handles non-existent file gracefully', () async {
        final result = await fileHandler.getFileMimeType('/non/existent/file');
        // The file command may return an error message instead of null
        expect(result, isNotNull);
      });

      test('returns MIME type for existing file', () async {
        // Create a temporary text file
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final textFile = File(path.join(tempDir.path, 'test.txt'));
        await textFile.writeAsString('Hello, World!');

        final result = await fileHandler.getFileMimeType(textFile.path);
        // Should return something like 'text/plain'
        expect(result, isNotNull);
        expect(result, contains('text'));

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('isValidAppImage', () {
      test('returns false for non-existent file', () async {
        final result = await fileHandler.isValidAppImage('/non/existent/file');
        expect(result, isFalse);
      });

      test('returns false for non-executable file', () async {
        // Create a temporary file without executable permissions
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final testFile = File(path.join(tempDir.path, 'test.AppImage'));
        await testFile.create();

        final result = await fileHandler.isValidAppImage(testFile.path);
        expect(result, isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });
  });
}
