import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/platform/interfaces/i_platform_file_handler.dart';
import '../../core/platform/interfaces/i_platform_installation_service.dart';
import '../../core/platform/platform_factory.dart';
import '../storage/preferences_service.dart';

class InstallationService {
  final PreferencesService _preferencesService;
  final IPlatformInstallationService _platformInstallationService;

  InstallationService(
    this._preferencesService, [
    IPlatformFileHandler? fileHandler,
  ]) : _platformInstallationService =
           PlatformFactory.createInstallationServiceWithServices(
             fileHandler ?? PlatformFactory.createFileHandler(),
             _preferencesService,
           );

  Future<String> getInstallPath() async {
    String? installPath = await _preferencesService.getInstallPath();

    if (installPath == null) {
      installPath = await _platformInstallationService.getDefaultInstallPath();
      await _preferencesService.setInstallPath(installPath);
    }

    await Directory(installPath).create(recursive: true);
    return installPath;
  }

  Future<String> getChannelInstallPath() async {
    final installPath = await getInstallPath();
    final channel = await _preferencesService.getReleaseChannel();
    final channelFolderName = _platformInstallationService.getChannelFolderName(
      channel,
    );
    return path.join(installPath, channelFolderName);
  }

  /// Organize extracted files into proper channel folder
  Future<void> organizeInstallation(String installPath) async {
    final channel = await _preferencesService.getReleaseChannel();
    await _platformInstallationService.organizeInstallation(
      installPath,
      channel,
    );
  }
}
