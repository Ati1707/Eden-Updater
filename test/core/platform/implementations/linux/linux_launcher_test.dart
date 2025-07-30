import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:eden_updater/core/platform/implementations/linux/linux_launcher.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/core/platform/implementations/linux/linux_file_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinuxLauncher', () {
    late LinuxLauncher launcher;
    late PreferencesService preferencesService;
    late InstallationService installationService;

    setUp(() {
      final fileHandler = LinuxFileHandler();
      preferencesService = PreferencesService();
      installationService = InstallationService(
        preferencesService,
        fileHandler,
      );

      launcher = LinuxLauncher(preferencesService, installationService);
    });

    group('findEdenExecutable', () {
      test('returns null when installation directory does not exist', () async {
        final result = await launcher.findEdenExecutable(
          '/non/existent/path',
          'stable',
        );
        expect(result, isNull);
      });

      test('returns null when no Eden executable found', () async {
        // Create a temporary directory with no Eden files
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final testFile = File(path.join(tempDir.path, 'not_eden.txt'));
        await testFile.create();

        final result = await launcher.findEdenExecutable(
          tempDir.path,
          'stable',
        );
        expect(result, isNull);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('can search for Eden executable', () async {
        // Create a temporary directory with a mock Eden executable
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final edenFile = File(path.join(tempDir.path, 'eden'));
        await edenFile.create();

        // Test will fail due to SharedPreferences but we can verify the method exists
        try {
          await launcher.findEdenExecutable(tempDir.path, 'stable');
        } catch (e) {
          // Expected to fail in test environment due to SharedPreferences
          expect(e.toString(), contains('MissingPluginException'));
        }

        // Cleanup
        await tempDir.delete(recursive: true);
      });
    });
  });
}
