import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/logging_service.dart';
import '../../models/update_info.dart';

/// Service for interacting with GitHub API
class GitHubApiService {
  /// Fetch the latest release information from GitHub
  Future<UpdateInfo> getLatestRelease(String channel) async {
    final apiUrl = channel == AppConstants.nightlyChannel
        ? AppConstants.nightlyApiUrl
        : AppConstants.stableApiUrl;

    LoggingService.info('Fetching latest release for channel: $channel');
    LoggingService.info('API URL: $apiUrl');

    Exception? lastException;

    for (int attempt = 1; attempt <= AppConstants.maxRetries; attempt++) {
      try {
        LoggingService.info(
          'GitHub API request attempt $attempt/${AppConstants.maxRetries}',
        );

        final response = await http
            .get(
              Uri.parse(apiUrl),
              headers: {'Accept': 'application/vnd.github.v3+json'},
            )
            .timeout(AppConstants.requestTimeout);

        LoggingService.info('GitHub API response: ${response.statusCode}');
        LoggingService.debug('Response headers: ${response.headers}');

        if (response.statusCode == 200) {
          LoggingService.info('Successfully received release data');

          try {
            final data = json.decode(response.body);
            LoggingService.debug('JSON decode successful');

            // Debug: Log assets information
            final assets = data['assets'] as List<dynamic>? ?? [];
            LoggingService.info('Found ${assets.length} assets in release');
            for (final asset in assets) {
              final name = asset['name'] as String? ?? 'unknown';
              final downloadUrl =
                  asset['browser_download_url'] as String? ?? 'no-url';
              final size = asset['size'] as int? ?? 0;
              LoggingService.debug(
                'Asset: $name, URL: $downloadUrl, Size: $size',
              );
            }

            final updateInfo = UpdateInfo.fromJson(data);
            LoggingService.info(
              'Parsed release info - Version: ${updateInfo.version}, URL: ${updateInfo.downloadUrl}',
            );

            return updateInfo;
          } catch (e) {
            LoggingService.error('Failed to parse JSON response', e);
            LoggingService.debug(
              'Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
            );
            throw NetworkException(
              'Failed to parse release data',
              e.toString(),
            );
          }
        } else {
          LoggingService.warning(
            'GitHub API returned error status: ${response.statusCode}',
          );
          LoggingService.debug('Error response body: ${response.body}');

          throw NetworkException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
            'Failed to fetch release from $apiUrl',
          );
        }
      } catch (e) {
        LoggingService.warning('GitHub API attempt $attempt failed', e);

        lastException = NetworkException(
          'Attempt $attempt failed',
          e.toString(),
        );

        if (attempt < AppConstants.maxRetries) {
          LoggingService.info(
            'Retrying in ${AppConstants.retryDelay.inSeconds} seconds...',
          );
          await Future.delayed(AppConstants.retryDelay);
        }
      }
    }

    LoggingService.error('All GitHub API attempts failed');
    throw NetworkException(
      'Failed to fetch latest release after ${AppConstants.maxRetries} attempts',
      lastException?.toString(),
    );
  }
}
