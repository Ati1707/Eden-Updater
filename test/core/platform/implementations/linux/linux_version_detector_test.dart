import 'package:flutter_test/flutter_test.dart';

import 'package:eden_updater/core/platform/implementations/linux/linux_version_detector.dart';
import 'package:eden_updater/services/installation/installation_service.dart';
import 'package:eden_updater/services/storage/preferences_service.dart';
import 'package:eden_updater/core/platform/implementations/linux/linux_file_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinuxVersionDetector', () {
    late LinuxVersionDetector versionDetector;
    late PreferencesService preferencesService;
    late InstallationService installationService;

    setUp(() {
      final fileHandler = LinuxFileHandler();
      preferencesService = PreferencesService();
      installationService = InstallationService(
        preferencesService,
        fileHandler,
      );

      versionDetector = LinuxVersionDetector(
        preferencesService,
        installationService,
      );
    });

    group('getInstallationMetadata', () {
      test('returns null when no metadata file exists', () async {
        final result = await versionDetector.getInstallationMetadata('stable');
        expect(result, isNull);
      });
    });

    group('basic functionality', () {
      test('can be instantiated', () {
        expect(versionDetector, isNotNull);
      });
    });
  });
}
