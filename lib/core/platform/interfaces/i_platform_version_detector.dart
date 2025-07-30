import '../../../models/update_info.dart';

abstract class IPlatformVersionDetector {
  Future<UpdateInfo?> getCurrentVersion(String channel);
  Future<void> storeVersionInfo(UpdateInfo updateInfo, String channel);
  Future<void> clearVersionInfo(String channel);
}
