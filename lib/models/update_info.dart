import 'dart:io' as io;
import 'dart:developer' as developer;
import '../core/utils/file_utils.dart';
import '../core/utils/date_utils.dart';

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

  /// Create UpdateInfo from GitHub API response
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

  /// Create a placeholder UpdateInfo for "not installed" state
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

  /// Create UpdateInfo from stored version data
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

  /// Check if this represents an installed version
  bool get isInstalled => version != 'Not installed';

  /// Check if this has a valid download URL
  bool get hasDownloadUrl => downloadUrl.isNotEmpty;

  /// Check if versions are different (for update comparison)
  bool isDifferentFrom(UpdateInfo? other) {
    if (other == null) return true;
    return version != other.version;
  }

  String get formattedFileSize => FileUtils.formatFileSize(fileSize);

  String get formattedReleaseDate => DateUtils.formatRelativeTime(releaseDate);
}

/// Helper class for finding platform-specific assets
class PlatformAssetFinder {
  static Map<String, dynamic>? findAsset(List<dynamic> assets) {
    if (io.Platform.isWindows) {
      return _findWindowsAsset(assets);
    } else if (io.Platform.isLinux) {
      return _findLinuxAsset(assets);
    } else if (io.Platform.isAndroid) {
      return _findAndroidAsset(assets);
    }
    return null;
  }

  static Map<String, dynamic>? _findWindowsAsset(List<dynamic> assets) {
    // Priority order for Windows assets
    final searchPatterns = [
      (String name) =>
          name.contains('windows') &&
          name.contains('x86_64') &&
          name.endsWith('.7z'),
      (String name) =>
          name.contains('windows') &&
          name.contains('amd64') &&
          name.endsWith('.zip'),
      (String name) =>
          name.contains('windows') &&
          (name.contains('x86_64') || name.contains('amd64')) &&
          (name.endsWith('.7z') || name.endsWith('.zip')),
      (String name) =>
          name.contains('windows') &&
          !name.contains('arm64') &&
          !name.contains('aarch64') &&
          (name.endsWith('.7z') || name.endsWith('.zip')),
    ];

    for (final pattern in searchPatterns) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (pattern(name)) {
          developer.log(
            'Found Windows build: ${asset['name']}',
            name: 'PlatformAssetFinder',
          );
          return asset;
        }
      }
    }

    developer.log(
      'No suitable Windows build found',
      name: 'PlatformAssetFinder',
    );
    return null;
  }

  static Map<String, dynamic>? _findLinuxAsset(List<dynamic> assets) {
    // Get system architecture synchronously by checking common indicators
    final systemArch = _getSystemArchitectureSync();

    developer.log(
      'Detected system architecture: $systemArch',
      name: 'PlatformAssetFinder',
    );

    // Priority order for Linux AppImage assets based on architecture
    final searchPatterns = _getLinuxSearchPatterns(systemArch);

    for (final pattern in searchPatterns) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (pattern(name)) {
          developer.log(
            'Found Linux AppImage: ${asset['name']} for architecture: $systemArch',
            name: 'PlatformAssetFinder',
          );
          return asset;
        }
      }
    }

    // Fallback: any Linux asset if architecture-specific not found
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if ((name.contains('appimage') && !name.contains('zsync')) ||
          name.contains('linux') ||
          name.endsWith('.tar.gz')) {
        developer.log(
          'Found fallback Linux asset: ${asset['name']}',
          name: 'PlatformAssetFinder',
        );
        return asset;
      }
    }

    developer.log('No suitable Linux asset found', name: 'PlatformAssetFinder');
    return null;
  }

  /// Get system architecture synchronously using environment variables and platform info
  static String _getSystemArchitectureSync() {
    if (!io.Platform.isLinux) {
      return 'amd64';
    }

    // Try to get architecture from environment variables first
    final envArch =
        io.Platform.environment['HOSTTYPE'] ??
        io.Platform.environment['MACHTYPE'] ??
        '';

    if (envArch.isNotEmpty) {
      final arch = envArch.toLowerCase();
      if (arch.contains('x86_64') || arch.contains('amd64')) {
        return 'amd64';
      } else if (arch.contains('aarch64') || arch.contains('arm64')) {
        return 'aarch64';
      } else if (arch.contains('arm')) {
        return 'armv9';
      }
    }

    // Default to amd64 for most common case
    return 'amd64';
  }

  /// Get search patterns for Linux assets based on architecture
  static List<bool Function(String)> _getLinuxSearchPatterns(String arch) {
    switch (arch) {
      case 'aarch64':
        return [
          // Stable releases: prefer aarch64 AppImages
          (String name) =>
              name.contains('appimage') &&
              name.contains('aarch64') &&
              !name.contains('zsync'),
          // Nightly releases: Linux-aarch64 pattern
          (String name) =>
              name.contains('appimage') &&
              name.contains('linux-aarch64') &&
              !name.contains('zsync'),
          // Nightly releases: light version
          (String name) =>
              name.contains('appimage') &&
              name.contains('linux-light-aarch64') &&
              !name.contains('zsync'),
          // Fallback to arm64 AppImages
          (String name) =>
              name.contains('appimage') &&
              name.contains('arm64') &&
              !name.contains('zsync'),
          // Generic Linux aarch64
          (String name) => name.contains('linux') && name.contains('aarch64'),
          // Any AppImage as last resort
          (String name) => name.contains('appimage') && !name.contains('zsync'),
        ];

      case 'armv9':
        return [
          // Stable releases: prefer armv9 AppImages
          (String name) =>
              name.contains('appimage') &&
              name.contains('armv9') &&
              !name.contains('zsync'),
          // Nightly releases: Legacy ARM builds
          (String name) =>
              name.contains('appimage') &&
              name.contains('legacy') &&
              name.contains('x86_64') &&
              !name.contains('zsync'),
          // Fallback to generic arm AppImages
          (String name) =>
              name.contains('appimage') &&
              name.contains('arm') &&
              !name.contains('aarch64') &&
              !name.contains('zsync'),
          // Any AppImage as last resort
          (String name) => name.contains('appimage') && !name.contains('zsync'),
        ];

      case 'amd64':
      default:
        return [
          // Stable releases: prefer amd64 AppImages
          (String name) =>
              name.contains('appimage') &&
              name.contains('amd64') &&
              !name.contains('zsync'),
          // Nightly releases: Common x86_64_v3 (best performance)
          (String name) =>
              name.contains('appimage') &&
              name.contains('common') &&
              name.contains('x86_64_v3') &&
              !name.contains('light') &&
              !name.contains('zsync'),
          // Nightly releases: Common light x86_64_v3 (smaller size)
          (String name) =>
              name.contains('appimage') &&
              name.contains('common-light') &&
              name.contains('x86_64_v3') &&
              !name.contains('zsync'),
          // Stable releases: x86_64 AppImages
          (String name) =>
              name.contains('appimage') &&
              name.contains('x86_64') &&
              !name.contains('steamdeck') &&
              !name.contains('rog') &&
              !name.contains('legacy') &&
              !name.contains('zsync'),
          // Nightly releases: Legacy x86_64 (better compatibility)
          (String name) =>
              name.contains('appimage') &&
              name.contains('legacy') &&
              name.contains('x86_64') &&
              !name.contains('light') &&
              !name.contains('zsync'),
          // Nightly releases: Legacy light x86_64
          (String name) =>
              name.contains('appimage') &&
              name.contains('legacy-light') &&
              name.contains('x86_64') &&
              !name.contains('zsync'),
          // Generic Linux AppImages (usually amd64)
          (String name) =>
              name.contains('appimage') &&
              name.contains('linux') &&
              !name.contains('aarch64') &&
              !name.contains('arm') &&
              !name.contains('zsync'),
          // Any AppImage without special device targeting
          (String name) =>
              name.contains('appimage') &&
              !name.contains('aarch64') &&
              !name.contains('arm') &&
              !name.contains('steamdeck') &&
              !name.contains('rog') &&
              !name.contains('zsync'),
        ];
    }
  }

  static Map<String, dynamic>? _findAndroidAsset(List<dynamic> assets) {
    // Debug: Log all available assets
    developer.log('Available assets for Android:', name: 'PlatformAssetFinder');
    for (final asset in assets) {
      final name = asset['name'] as String? ?? 'unknown';
      final size = asset['size'] as int? ?? 0;
      developer.log('  - $name ($size bytes)', name: 'PlatformAssetFinder');
    }

    // Priority order for Android assets:
    // 1. Standard Android APK (Eden-Android-vX.X.X.apk)
    // 2. Any APK file
    // 3. Any file with 'android' in the name

    // First, look for the standard Android APK (not Legacy or Optimized)
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if ((name.contains('android') || name.endsWith('.apk')) &&
          !name.contains('legacy') &&
          !name.contains('optimized')) {
        developer.log(
          'Found standard Android APK: ${asset['name']}',
          name: 'PlatformAssetFinder',
        );
        return asset;
      }
    }

    // Second, look for any APK file
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        developer.log(
          'Found APK file: ${asset['name']}',
          name: 'PlatformAssetFinder',
        );
        return asset;
      }
    }

    // Third, look for any file with 'android' in the name
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('android')) {
        developer.log(
          'Found Android asset: ${asset['name']}',
          name: 'PlatformAssetFinder',
        );
        return asset;
      }
    }

    // Fourth, for nightly builds, look for common mobile patterns
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('mobile') ||
          name.contains('arm64') ||
          name.contains('aarch64')) {
        developer.log(
          'Found potential mobile asset: ${asset['name']}',
          name: 'PlatformAssetFinder',
        );
        return asset;
      }
    }

    developer.log('No suitable Android APK found', name: 'PlatformAssetFinder');
    return null;
  }
}
