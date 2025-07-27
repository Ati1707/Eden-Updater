import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../core/errors/app_exceptions.dart';
import '../../core/services/logging_service.dart';
import '../../models/update_info.dart';

/// Service for downloading files
class DownloadService {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Download a file with progress tracking and retry logic
  Future<String> downloadFile(
    UpdateInfo updateInfo,
    String downloadPath, {
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    LoggingService.info('Starting download from: ${updateInfo.downloadUrl}');
    LoggingService.info('Download destination: $downloadPath');

    final fileName = path.basename(Uri.parse(updateInfo.downloadUrl).path);
    final filePath = path.join(downloadPath, fileName);

    LoggingService.info('Download filename: $fileName');
    LoggingService.info('Full download path: $filePath');

    return await _downloadWithRetry(
      updateInfo,
      downloadPath,
      fileName,
      filePath,
      onProgress,
      onStatusUpdate,
    );
  }

  /// Download with retry logic
  Future<String> _downloadWithRetry(
    UpdateInfo updateInfo,
    String downloadPath,
    String fileName,
    String filePath,
    Function(double) onProgress,
    Function(String) onStatusUpdate,
  ) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LoggingService.info('Download attempt $attempt/$maxRetries');

        if (attempt > 1) {
          onStatusUpdate('Retrying download... (attempt $attempt/$maxRetries)');
          await Future.delayed(retryDelay);
        }

        return await _performDownload(
          updateInfo,
          filePath,
          onProgress,
          onStatusUpdate,
        );
      } catch (error) {
        LoggingService.warning('Download attempt $attempt failed', error);

        if (attempt == maxRetries) {
          LoggingService.error('All download attempts failed', error);
          rethrow;
        }

        // Clean up partial file before retry
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            LoggingService.info('Cleaned up partial file before retry');
          }
        } catch (cleanupError) {
          LoggingService.warning(
            'Failed to clean up before retry',
            cleanupError,
          );
        }
      }
    }

    throw FileException(
      'Download failed after $maxRetries attempts',
      'All retry attempts exhausted',
    );
  }

  /// Perform the actual download
  Future<String> _performDownload(
    UpdateInfo updateInfo,
    String filePath,
    Function(double) onProgress,
    Function(String) onStatusUpdate,
  ) async {
    final client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));

      // Add headers to improve connection stability
      request.headers.addAll({
        'User-Agent': 'Eden-Updater/1.0',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      });

      LoggingService.info('Sending HTTP GET request...');

      final response = await client
          .send(request)
          .timeout(
            const Duration(minutes: 10),
            onTimeout: () {
              throw TimeoutException('Download timeout after 10 minutes');
            },
          );

      LoggingService.info('Received HTTP response: ${response.statusCode}');
      LoggingService.info(
        'Content length: ${response.contentLength ?? 'unknown'}',
      );
      LoggingService.info(
        'Content type: ${response.headers['content-type'] ?? 'unknown'}',
      );

      if (response.statusCode != 200) {
        LoggingService.error(
          'HTTP request failed with status ${response.statusCode}',
        );
        LoggingService.error('Response headers: ${response.headers}');
        throw NetworkException(
          'Failed to download file',
          'HTTP ${response.statusCode} from ${updateInfo.downloadUrl}',
        );
      }

      final file = File(filePath);
      final sink = file.openWrite();

      int downloaded = 0;
      final total = response.contentLength ?? 0;
      LoggingService.info('Starting file write, expected size: $total bytes');

      try {
        onStatusUpdate('Downloading...');
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (total > 0) {
            final downloadProgress = downloaded / total;
            onProgress(downloadProgress);
            onStatusUpdate(
              'Downloading... ${(downloadProgress * 100).toInt()}%',
            );
          }
        }

        await sink.close();

        final actualSize = await file.length();
        LoggingService.info('Download completed successfully');
        LoggingService.info(
          'Downloaded $downloaded bytes, file size: $actualSize bytes',
        );

        if (total > 0 && actualSize != total) {
          LoggingService.warning(
            'File size mismatch - expected: $total, actual: $actualSize',
          );
        }

        return filePath;
      } catch (error) {
        LoggingService.error('Error during file download', error);
        await sink.close();

        // Try to clean up partial file
        try {
          if (await file.exists()) {
            await file.delete();
            LoggingService.info('Cleaned up partial download file');
          }
        } catch (cleanupError) {
          LoggingService.warning(
            'Failed to clean up partial download',
            cleanupError,
          );
        }

        throw FileException('Download failed', error.toString());
      }
    } catch (error) {
      LoggingService.error('Download operation failed', error);
      rethrow;
    } finally {
      client.close();
    }
  }
}
