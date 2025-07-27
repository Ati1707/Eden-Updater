import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/file_utils.dart';
import '../../core/services/logging_service.dart';

/// Service for extracting archive files
class ExtractionService {
  /// Extract an archive file to a destination directory
  Future<void> extractArchive(
    String archivePath,
    String destinationPath, {
    Function(double)? onProgress,
  }) async {
    LoggingService.info('Starting extraction of: $archivePath');
    LoggingService.info('Destination: $destinationPath');
    LoggingService.info('File extension: ${path.extension(archivePath)}');

    final file = File(archivePath);
    if (!await file.exists()) {
      LoggingService.error('Archive file does not exist: $archivePath');
      throw FileException('Archive file not found', archivePath);
    }

    final fileSize = await file.length();
    LoggingService.info('Archive file size: $fileSize bytes');

    final bytes = await file.readAsBytes();
    LoggingService.info('Successfully read ${bytes.length} bytes from archive');

    Archive archive;
    final extension = path.extension(archivePath).toLowerCase();
    LoggingService.info('Processing archive with extension: $extension');

    if (extension == '.zip') {
      LoggingService.info('Detected ZIP archive format');
      try {
        archive = ZipDecoder().decodeBytes(bytes);
        LoggingService.info(
          'Successfully decoded ZIP archive with ${archive.files.length} files',
        );
      } catch (e) {
        LoggingService.error('Failed to decode ZIP archive', e);
        throw ExtractionException('Failed to decode ZIP archive', e.toString());
      }
    } else if (extension == '.gz' && archivePath.endsWith('.tar.gz')) {
      LoggingService.info('Detected TAR.GZ archive format');
      try {
        final decompressed = GZipDecoder().decodeBytes(bytes);
        LoggingService.info('Successfully decompressed GZIP, now decoding TAR');
        archive = TarDecoder().decodeBytes(decompressed);
        LoggingService.info(
          'Successfully decoded TAR archive with ${archive.files.length} files',
        );
      } catch (e) {
        LoggingService.error('Failed to decode TAR.GZ archive', e);
        throw ExtractionException(
          'Failed to decode TAR.GZ archive',
          e.toString(),
        );
      }
    } else if (extension == '.7z') {
      LoggingService.info('Detected 7Z archive format, using external tool');
      await _extract7z(archivePath, destinationPath, onProgress: onProgress);
      return;
    } else {
      LoggingService.error('Unsupported archive format detected');
      LoggingService.error('Archive path: $archivePath');
      LoggingService.error('File extension: $extension');
      LoggingService.error('Full filename: ${path.basename(archivePath)}');

      // Log file signature for debugging
      if (bytes.length >= 4) {
        final signature = bytes
            .take(4)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        LoggingService.error('File signature (first 4 bytes): $signature');
      }

      // Check if it's actually an APK file (Android Package)
      if (bytes.length >= 4) {
        final signature = bytes.take(4);
        // APK files are ZIP files, so they start with PK (0x504B)
        if (signature.first == 0x50 && signature.elementAt(1) == 0x4B) {
          LoggingService.info(
            'File appears to be a ZIP/APK based on signature',
          );
          if (Platform.isAndroid) {
            LoggingService.info('Treating as APK file on Android platform');
            // This should be handled by the update service, not here
            throw ExtractionException(
              'APK file detected but not handled properly',
              'This appears to be an APK file that should be installed directly on Android',
            );
          }
        }
      }

      throw ExtractionException(
        'Unsupported archive format: $extension',
        'File: ${path.basename(archivePath)}, Size: $fileSize bytes, Signature: ${bytes.length >= 4 ? bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ') : 'unknown'}',
      );
    }

    int extractedFiles = 0;
    final totalFiles = archive.files.where((f) => f.isFile).length;
    LoggingService.info('Archive contains $totalFiles files to extract');

    try {
      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          final extractPath = path.join(destinationPath, file.name);
          LoggingService.debug(
            'Extracting file: ${file.name} (${data.length} bytes)',
          );

          await Directory(path.dirname(extractPath)).create(recursive: true);
          await File(extractPath).writeAsBytes(data);
          extractedFiles++;

          if (onProgress != null && totalFiles > 0) {
            onProgress(extractedFiles / totalFiles);
          }

          // Make executable if it's an Eden executable on Linux
          if (Platform.isLinux && FileUtils.isEdenExecutable(file.name)) {
            LoggingService.debug('Making file executable: ${file.name}');
            await Process.run('chmod', ['+x', extractPath]);
          }
        }
      }

      LoggingService.info('Successfully extracted $extractedFiles files');
      await file.delete();
      LoggingService.info('Cleaned up archive file: $archivePath');
    } catch (e) {
      LoggingService.error('Error during file extraction', e);
      throw ExtractionException('Failed to extract files', e.toString());
    }
  }

  /// Extract 7z archives using system 7z command
  Future<void> _extract7z(
    String archivePath,
    String destinationPath, {
    Function(double)? onProgress,
  }) async {
    try {
      ProcessResult result;
      if (Platform.isWindows) {
        final sevenZipPaths = [
          'C:\\Program Files\\7-Zip\\7z.exe',
          'C:\\Program Files (x86)\\7-Zip\\7z.exe',
          '7z',
        ];

        String? workingPath;
        for (final szPath in sevenZipPaths) {
          try {
            result = await Process.run(szPath, ['--help'], runInShell: true);
            if (result.exitCode == 0) {
              workingPath = szPath;
              break;
            }
          } catch (e) {
            continue;
          }
        }

        if (workingPath != null) {
          result = await Process.run(workingPath, [
            'x',
            archivePath,
            '-o$destinationPath',
            '-y',
          ], runInShell: true);

          if (result.exitCode == 0) {
            onProgress?.call(1.0);
            return;
          }
        }
      } else {
        result = await Process.run('7z', [
          'x',
          archivePath,
          '-o$destinationPath',
          '-y',
        ]);
        if (result.exitCode == 0) {
          onProgress?.call(1.0);
          return;
        }
      }
    } catch (e) {
      // Fall through to throw exception
    }

    throw ExtractionException(
      '7z extraction failed',
      'Please install 7-Zip:\n'
          'Windows: Download from https://www.7-zip.org/\n'
          'Linux: sudo apt install p7zip-full',
    );
  }
}
