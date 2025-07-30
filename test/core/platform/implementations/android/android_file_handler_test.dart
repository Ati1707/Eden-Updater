import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:eden_updater/core/platform/implementations/android/android_file_handler.dart';

void main() {
  group('AndroidFileHandler', () {
    late AndroidFileHandler fileHandler;

    setUp(() {
      fileHandler = AndroidFileHandler();
    });

    group('isEdenExecutable', () {
      test('returns true for APK files containing "eden"', () {
        expect(fileHandler.isEdenExecutable('eden.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('EDEN.APK'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-stable.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('eden-nightly.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('eden_emulator.apk'), isTrue);
        expect(fileHandler.isEdenExecutable('Eden_v1.0.0.apk'), isTrue);
      });

      test('returns false for non-APK files', () {
        expect(fileHandler.isEdenExecutable('eden.exe'), isFalse);
        expect(fileHandler.isEdenExecutable('eden.zip'), isFalse);
        expect(fileHandler.isEdenExecutable('eden'), isFalse);
        expect(fileHandler.isEdenExecutable('test.apk'), isFalse);
        expect(fileHandler.isEdenExecutable('other.apk'), isFalse);
      });

      test('returns false for empty or invalid filenames', () {
        expect(fileHandler.isEdenExecutable(''), isFalse);
        expect(fileHandler.isEdenExecutable('.apk'), isFalse);
        expect(fileHandler.isEdenExecutable('eden.'), isFalse);
      });
    });

    group('getEdenExecutablePath', () {
      test('returns correct path for stable channel', () {
        final path = fileHandler.getEdenExecutablePath('/test/path', 'stable');
        expect(path, equals('/test/path/eden-stable.apk'));
      });

      test('returns correct path for nightly channel', () {
        final path = fileHandler.getEdenExecutablePath('/test/path', 'nightly');
        expect(path, equals('/test/path/eden-nightly.apk'));
      });

      test('returns default path when channel is null', () {
        final path = fileHandler.getEdenExecutablePath('/test/path', null);
        expect(path, equals('/test/path/eden.apk'));
      });

      test('returns default path for unknown channel', () {
        final path = fileHandler.getEdenExecutablePath('/test/path', 'unknown');
        expect(path, equals('/test/path/eden-stable.apk'));
      });
    });

    group('makeExecutable', () {
      test('completes without error (no-op on Android)', () async {
        // Should complete without throwing
        await fileHandler.makeExecutable('/test/path/eden.apk');
      });
    });

    group('containsEdenFiles', () {
      test('returns false for non-existent directory', () async {
        final result = await fileHandler.containsEdenFiles(
          '/non/existent/path',
        );
        expect(result, isFalse);
      });

      test('returns true when directory contains Eden APK files', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final apkFile = File('${tempDir.path}/eden.apk');
        await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // ZIP signature

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false when directory contains no Eden files', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final txtFile = File('${tempDir.path}/test.txt');
        await txtFile.writeAsString('test content');

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('handles recursive directory search', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final subDir = Directory('${tempDir.path}/subdir');
        await subDir.create();
        final apkFile = File('${subDir.path}/eden-nightly.apk');
        await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // ZIP signature

        final result = await fileHandler.containsEdenFiles(tempDir.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });

    group('isApkFile', () {
      test('returns true for files with .apk extension', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final apkFile = File('${tempDir.path}/test.apk');
        await apkFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // ZIP signature

        final result = await fileHandler.isApkFile(apkFile.path);

        expect(result, isTrue);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for non-APK files', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final txtFile = File('${tempDir.path}/test.txt');
        await txtFile.writeAsString('test content');

        final result = await fileHandler.isApkFile(txtFile.path);

        expect(result, isFalse);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('returns false for non-existent files', () async {
        final result = await fileHandler.isApkFile('/non/existent/file.apk');

        expect(result, isFalse);
      });
    });

    group('Android-specific methods', () {
      test('getDownloadsPath returns correct Android path', () {
        final path = fileHandler.getDownloadsPath();
        expect(path, equals('/storage/emulated/0/Download'));
      });

      test('getExternalStoragePath returns correct Android path', () {
        final path = fileHandler.getExternalStoragePath();
        expect(path, equals('/storage/emulated/0'));
      });

      test('getAppExternalFilesPath returns correct Android app path', () {
        final path = fileHandler.getAppExternalFilesPath();
        expect(
          path,
          equals(
            '/storage/emulated/0/Android/data/com.example.eden_updater/files',
          ),
        );
      });

      test('isExternalStorageWritable handles non-existent storage', () async {
        // In test environment, Android external storage won't exist
        final result = await fileHandler.isExternalStorageWritable();
        expect(result, isFalse);
      });

      test('ensureAndroidDirectories handles directory creation', () async {
        // Should complete without throwing, even if directories can't be created
        await fileHandler.ensureAndroidDirectories();
      });
    });
  });
}
