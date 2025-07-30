import 'dart:developer' as developer;
import '../core/utils/file_utils.dart';
import '../core/utils/date_utils.dart';
import '../core/platform/platform_factory.dart';
import '../core/platform/models/platform_config.dart';

/// Represents information about an Eden update/release
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime releaseDate;
  final int fileSize;
  final String releaseUrl;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
    required this.fileSize,
    required this.releaseUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>? ?? [];
    final platformAsset = PlatformAssetFinder.findAsset(assets);

    return UpdateInfo(
      version: _extractVersion(json),
      downloadUrl: platformAsset?['browser_download_url'] as String? ?? '',
      releaseNotes: json['body'] as String? ?? '',
      releaseDate: _parseReleaseDate(json['published_at'] as String?),
      fileSize: platformAsset?['size'] as int? ?? 0,
      releaseUrl: json['html_url'] as String? ?? '',
    );
  }

  factory UpdateInfo.notInstalled() {
    return UpdateInfo(
      version: 'Not installed',
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
      releaseUrl: '',
    );
  }

  factory UpdateInfo.fromStoredVersion(String version) {
    return UpdateInfo(
      version: version,
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
      releaseUrl: '',
    );
  }

  static String _extractVersion(Map<String, dynamic> json) {
    return json['tag_name'] as String? ?? json['name'] as String? ?? 'Unknown';
  }

  static DateTime _parseReleaseDate(String? dateString) {
    if (dateString == null) return DateTime.now();
    return DateTime.tryParse(dateString) ?? DateTime.now();
  }

  bool get isInstalled => version != 'Not installed';
  bool get hasDownloadUrl => downloadUrl.isNotEmpty;
  bool isDifferentFrom(UpdateInfo? other) {
    if (other == null) return true;
    return version != other.version;
  }

  String get formattedFileSize => FileUtils.formatFileSize(fileSize);

  String get formattedReleaseDate => DateUtils.formatRelativeTime(releaseDate);
}

class PlatformAssetFinder {
  static Map<String, dynamic>? findAsset(List<dynamic> assets) {
    try {
      // Use platform factory to get current platform configuration
      final config = PlatformFactory.getCurrentPlatformConfig();
      return _findAssetForPlatform(assets, config);
    } catch (e) {
      developer.log(
        'Failed to detect platform for asset finding: $e',
        name: 'PlatformAssetFinder',
      );
      return null;
    }
  }

  /// Find asset using platform configuration instead of hardcoded platform checks
  static Map<String, dynamic>? _findAssetForPlatform(
    List<dynamic> assets,
    PlatformConfig config,
  ) {
    developer.log(
      'Finding asset for platform: ${config.name}',
      name: 'PlatformAssetFinder',
    );

    // Use platform-specific search patterns from configuration
    for (final pattern in config.assetSearchPatterns) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (pattern(name)) {
          developer.log(
            'Found ${config.name} asset: ${asset['name']}',
            name: 'PlatformAssetFinder',
          );
          return asset;
        }
      }
    }

    // Fallback: try to find any asset with supported file extensions
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      for (final extension in config.supportedFileExtensions) {
        if (name.endsWith(extension.toLowerCase())) {
          developer.log(
            'Found fallback ${config.name} asset: ${asset['name']}',
            name: 'PlatformAssetFinder',
          );
          return asset;
        }
      }
    }

    developer.log(
      'No suitable ${config.name} asset found',
      name: 'PlatformAssetFinder',
    );
    return null;
  }
}
