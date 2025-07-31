import 'dart:io';
import 'package:path/path.dart' as path;
import '../../interfaces/i_platform_installation_service.dart';
import '../../../services/logging_service.dart';
import '../../../errors/app_exceptions.dart';
import '../../../../services/storage/preferences_service.dart';
import '../../interfaces/i_platform_file_handler.dart';

/// macOS-specific installation service implementation
class MacOSInstallationService implements IPlatformInstallationService {
  final IPlatformFileHandler _fileHandler;
  final PreferencesService _preferencesService;

  MacOSInstallationService(this._fileHandler, this._preferencesService);

  @override
  Future<String> getDefaultInstallPath() async {
    LoggingService.debug('[macOS] Getting default installation directory');

    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) {
        LoggingService.error('[macOS] HOME environment variable not found');
        throw UpdateException('HOME environment variable not found', '');
      }

      final defaultDir = path.join(homeDir, 'Documents', 'Eden');
      LoggingService.debug(
        '[macOS] Default installation directory: $defaultDir',
      );

      return defaultDir;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error getting default installation directory',
        e,
      );
      rethrow;
    }
  }

  @override
  String getChannelFolderName(String channel) {
    return channel == 'nightly' ? 'Eden-Nightly' : 'Eden-Release';
  }

  @override
  Future<void> organizeInstallation(String installPath, String channel) async {
    LoggingService.debug(
      '[macOS] Organizing installation for channel: $channel',
    );

    try {
      // For macOS, the installation is already organized during the install process
      // This method is mainly for compatibility with the interface
      LoggingService.debug('[macOS] Installation organization completed');
    } catch (e) {
      LoggingService.error('[macOS] Error organizing installation', e);
      rethrow;
    }
  }

  @override
  Future<void> scanAndStoreEdenExecutable(
    String installPath,
    String channel,
  ) async {
    LoggingService.debug('[macOS] Scanning and storing Eden executable');

    try {
      final edenPath = _fileHandler.getEdenExecutablePath(installPath, channel);

      if (await File(edenPath).exists()) {
        // Store the executable path in preferences
        await _preferencesService.setEdenExecutablePath(channel, edenPath);
        LoggingService.info('[macOS] Stored Eden executable path: $edenPath');
      } else {
        LoggingService.warning('[macOS] Eden executable not found: $edenPath');
      }
    } catch (e) {
      LoggingService.error(
        '[macOS] Error scanning and storing Eden executable',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> cleanEdenFolder(String edenPath) async {
    LoggingService.debug('[macOS] Cleaning Eden folder: $edenPath');

    try {
      final edenDir = Directory(edenPath);

      if (await edenDir.exists()) {
        // Remove all contents except user folder
        await for (final entity in edenDir.list()) {
          if (entity is Directory && path.basename(entity.path) == 'user') {
            // Skip user folder to preserve user data
            LoggingService.debug(
              '[macOS] Preserving user folder: ${entity.path}',
            );
            continue;
          }

          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
            LoggingService.debug('[macOS] Deleted: ${entity.path}');
          } catch (e) {
            LoggingService.warning(
              '[macOS] Could not delete: ${entity.path}',
              e,
            );
          }
        }

        LoggingService.debug('[macOS] Eden folder cleaned successfully');
      }
    } catch (e) {
      LoggingService.error('[macOS] Error cleaning Eden folder', e);
      rethrow;
    }
  }

  @override
  Future<void> mergeEdenFolder(String sourcePath, String targetPath) async {
    LoggingService.debug(
      '[macOS] Merging Eden folder: $sourcePath -> $targetPath',
    );

    try {
      await copyDirectory(sourcePath, targetPath);
      LoggingService.debug('[macOS] Eden folder merged successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error merging Eden folder', e);
      rethrow;
    }
  }

  @override
  Future<void> copyDirectory(String sourcePath, String targetPath) async {
    LoggingService.debug(
      '[macOS] Copying directory: $sourcePath -> $targetPath',
    );

    try {
      // Use cp -R for efficient directory copying on macOS
      final result = await Process.run('cp', ['-R', sourcePath, targetPath]);

      if (result.exitCode != 0) {
        LoggingService.error('[macOS] Directory copy failed: ${result.stderr}');
        throw UpdateException('Failed to copy directory', sourcePath);
      }

      LoggingService.debug('[macOS] Directory copied successfully');
    } catch (e) {
      LoggingService.error('[macOS] Error copying directory', e);
      rethrow;
    }
  }

  /// Get installation directory for channel (helper method)
  Future<String> getInstallationDirectory(String channel) async {
    final baseDir = await getDefaultInstallPath();
    final channelDir = getChannelFolderName(channel);
    return path.join(baseDir, channelDir);
  }

  /// Validates that a directory exists and is writable
  Future<bool> validateDirectory(String directoryPath) async {
    LoggingService.debug('[macOS] Validating directory: $directoryPath');

    try {
      final directory = Directory(directoryPath);

      // Check if directory exists
      if (!await directory.exists()) {
        LoggingService.debug(
          '[macOS] Directory does not exist: $directoryPath',
        );
        return false;
      }

      // Check write permissions by attempting to create a temporary file
      final tempFile = File(path.join(directoryPath, '.eden_write_test'));
      try {
        await tempFile.writeAsString('test');
        await tempFile.delete();
        LoggingService.debug('[macOS] Directory is writable: $directoryPath');
        return true;
      } catch (e) {
        LoggingService.warning(
          '[macOS] Directory is not writable: $directoryPath',
          e,
        );
        return false;
      }
    } catch (e) {
      LoggingService.error(
        '[macOS] Error validating directory: $directoryPath',
        e,
      );
      return false;
    }
  }

  /// Creates directory with proper permissions if it doesn't exist
  Future<void> createDirectory(String directoryPath) async {
    LoggingService.debug('[macOS] Creating directory: $directoryPath');

    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
        LoggingService.info('[macOS] Created directory: $directoryPath');

        // Set proper permissions (755 - owner: rwx, group: rx, others: rx)
        final result = await Process.run('chmod', ['755', directoryPath]);
        if (result.exitCode != 0) {
          LoggingService.warning(
            '[macOS] Failed to set directory permissions: ${result.stderr}',
          );
        } else {
          LoggingService.debug(
            '[macOS] Set directory permissions: $directoryPath',
          );
        }
      } else {
        LoggingService.debug(
          '[macOS] Directory already exists: $directoryPath',
        );
      }
    } catch (e) {
      LoggingService.error(
        '[macOS] Error creating directory: $directoryPath',
        e,
      );
      throw UpdateException(
        'Failed to create directory: $directoryPath',
        directoryPath,
      );
    }
  }

  /// Checks if the current user has write permissions for a directory
  Future<bool> hasWritePermission(String directoryPath) async {
    LoggingService.debug(
      '[macOS] Checking write permission for: $directoryPath',
    );

    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        LoggingService.debug(
          '[macOS] Directory does not exist, checking parent: $directoryPath',
        );
        // Check parent directory if this one doesn't exist
        final parentPath = path.dirname(directoryPath);
        if (parentPath != directoryPath) {
          return await hasWritePermission(parentPath);
        }
        return false;
      }

      // Use stat command to check permissions
      final result = await Process.run('stat', ['-f', '%A', directoryPath]);
      if (result.exitCode == 0) {
        final permissions = result.stdout.toString().trim();
        LoggingService.debug(
          '[macOS] Directory permissions: $permissions for $directoryPath',
        );

        // Check if owner has write permission (second digit should be >= 2)
        if (permissions.length >= 3) {
          final ownerPerms = int.tryParse(permissions[1]) ?? 0;
          final hasWrite = ownerPerms >= 2;
          LoggingService.debug(
            '[macOS] Write permission check result: $hasWrite',
          );
          return hasWrite;
        }
      }

      // Fallback: try to create a temporary file
      return await validateDirectory(directoryPath);
    } catch (e) {
      LoggingService.error(
        '[macOS] Error checking write permission: $directoryPath',
        e,
      );
      return false;
    }
  }

  /// Ensures installation directory exists and is writable
  Future<void> ensureInstallationDirectory(String channel) async {
    LoggingService.debug(
      '[macOS] Ensuring installation directory for channel: $channel',
    );

    try {
      final installDir = await getInstallationDirectory(channel);

      // Create directory if it doesn't exist
      await createDirectory(installDir);

      // Validate directory is writable
      if (!await validateDirectory(installDir)) {
        throw UpdateException(
          'Installation directory is not writable: $installDir',
          installDir,
        );
      }

      LoggingService.info('[macOS] Installation directory ready: $installDir');
    } catch (e) {
      LoggingService.error(
        '[macOS] Error ensuring installation directory for channel: $channel',
        e,
      );
      rethrow;
    }
  }

  /// Gets the size of a directory in bytes
  Future<int> getDirectorySize(String directoryPath) async {
    LoggingService.debug('[macOS] Calculating directory size: $directoryPath');

    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        LoggingService.debug(
          '[macOS] Directory does not exist: $directoryPath',
        );
        return 0;
      }

      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            LoggingService.warning(
              '[macOS] Could not get size for file: ${entity.path}',
              e,
            );
          }
        }
      }

      LoggingService.debug(
        '[macOS] Directory size: $totalSize bytes for $directoryPath',
      );
      return totalSize;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error calculating directory size: $directoryPath',
        e,
      );
      return 0;
    }
  }

  /// Detects if Eden is installed for the given channel
  Future<bool> isEdenInstalled(String channel) async {
    LoggingService.debug(
      '[macOS] Checking if Eden is installed for channel: $channel',
    );

    try {
      final installDir = await getInstallationDirectory(channel);
      final directory = Directory(installDir);

      if (!await directory.exists()) {
        LoggingService.debug(
          '[macOS] Installation directory does not exist: $installDir',
        );
        return false;
      }

      // Check if directory contains Eden files
      final hasEdenFiles = await _fileHandler.containsEdenFiles(installDir);
      LoggingService.debug(
        '[macOS] Eden installation detected: $hasEdenFiles for $channel',
      );

      return hasEdenFiles;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error checking Eden installation for channel: $channel',
        e,
      );
      return false;
    }
  }

  /// Gets the installation size for the given channel
  Future<int> getInstallationSize(String channel) async {
    LoggingService.debug(
      '[macOS] Getting installation size for channel: $channel',
    );

    try {
      final installDir = await getInstallationDirectory(channel);
      return await getDirectorySize(installDir);
    } catch (e) {
      LoggingService.error(
        '[macOS] Error getting installation size for channel: $channel',
        e,
      );
      return 0;
    }
  }

  /// Creates a backup of the Eden installation
  Future<String?> createBackup(String channel) async {
    LoggingService.debug('[macOS] Creating backup for channel: $channel');

    try {
      final installDir = await getInstallationDirectory(channel);
      final directory = Directory(installDir);

      if (!await directory.exists()) {
        LoggingService.warning(
          '[macOS] No installation to backup for channel: $channel',
        );
        return null;
      }

      // Create backup directory with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupName = '${getChannelFolderName(channel)}_backup_$timestamp';
      final baseDir = await getDefaultInstallPath();
      final backupPath = path.join(baseDir, 'backups', backupName);

      await createDirectory(path.dirname(backupPath));

      // Use cp -R for efficient backup on macOS
      final result = await Process.run('cp', ['-R', installDir, backupPath]);

      if (result.exitCode != 0) {
        LoggingService.error(
          '[macOS] Backup creation failed: ${result.stderr}',
        );
        throw UpdateException('Failed to create backup', installDir);
      }

      LoggingService.info('[macOS] Backup created successfully: $backupPath');
      return backupPath;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error creating backup for channel: $channel',
        e,
      );
      rethrow;
    }
  }

  /// Restores Eden installation from backup
  Future<void> restoreFromBackup(String channel, String backupPath) async {
    LoggingService.debug(
      '[macOS] Restoring from backup: $backupPath for channel: $channel',
    );

    try {
      final backupDir = Directory(backupPath);

      if (!await backupDir.exists()) {
        throw UpdateException('Backup directory does not exist', backupPath);
      }

      final installDir = await getInstallationDirectory(channel);

      // Remove current installation if it exists
      final currentDir = Directory(installDir);
      if (await currentDir.exists()) {
        await currentDir.delete(recursive: true);
        LoggingService.debug(
          '[macOS] Removed current installation: $installDir',
        );
      }

      // Restore from backup using cp -R
      final result = await Process.run('cp', ['-R', backupPath, installDir]);

      if (result.exitCode != 0) {
        LoggingService.error(
          '[macOS] Restore from backup failed: ${result.stderr}',
        );
        throw UpdateException('Failed to restore from backup', backupPath);
      }

      // Scan and store the restored executable
      await scanAndStoreEdenExecutable(installDir, channel);

      LoggingService.info(
        '[macOS] Successfully restored from backup: $backupPath',
      );
    } catch (e) {
      LoggingService.error(
        '[macOS] Error restoring from backup: $backupPath',
        e,
      );
      rethrow;
    }
  }

  /// Lists available backups for the given channel
  Future<List<String>> listBackups(String channel) async {
    LoggingService.debug('[macOS] Listing backups for channel: $channel');

    try {
      final baseDir = await getDefaultInstallPath();
      final backupsDir = Directory(path.join(baseDir, 'backups'));

      if (!await backupsDir.exists()) {
        LoggingService.debug('[macOS] No backups directory found');
        return [];
      }

      final channelPrefix = '${getChannelFolderName(channel)}_backup_';
      final backups = <String>[];

      await for (final entity in backupsDir.list()) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          if (name.startsWith(channelPrefix)) {
            backups.add(entity.path);
          }
        }
      }

      // Sort by creation time (newest first)
      backups.sort((a, b) {
        final aName = path.basename(a);
        final bName = path.basename(b);
        final aTimestamp = aName.split('_').last;
        final bTimestamp = bName.split('_').last;
        return bTimestamp.compareTo(aTimestamp);
      });

      LoggingService.debug(
        '[macOS] Found ${backups.length} backups for channel: $channel',
      );
      return backups;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error listing backups for channel: $channel',
        e,
      );
      return [];
    }
  }

  /// Removes old backups, keeping only the specified number
  Future<void> cleanupOldBackups(String channel, {int keepCount = 3}) async {
    LoggingService.debug(
      '[macOS] Cleaning up old backups for channel: $channel, keeping: $keepCount',
    );

    try {
      final backups = await listBackups(channel);

      if (backups.length <= keepCount) {
        LoggingService.debug('[macOS] No old backups to clean up');
        return;
      }

      final backupsToRemove = backups.skip(keepCount);

      for (final backupPath in backupsToRemove) {
        try {
          final backupDir = Directory(backupPath);
          await backupDir.delete(recursive: true);
          LoggingService.debug('[macOS] Removed old backup: $backupPath');
        } catch (e) {
          LoggingService.warning(
            '[macOS] Failed to remove backup: $backupPath',
            e,
          );
        }
      }

      LoggingService.info(
        '[macOS] Cleaned up ${backupsToRemove.length} old backups for channel: $channel',
      );
    } catch (e) {
      LoggingService.error(
        '[macOS] Error cleaning up old backups for channel: $channel',
        e,
      );
    }
  }

  /// Gets information about the Eden installation
  Future<Map<String, dynamic>> getInstallationInfo(String channel) async {
    LoggingService.debug(
      '[macOS] Getting installation info for channel: $channel',
    );

    try {
      final installDir = await getInstallationDirectory(channel);
      final isInstalled = await isEdenInstalled(channel);
      final size = isInstalled ? await getInstallationSize(channel) : 0;
      final backups = await listBackups(channel);

      final info = {
        'channel': channel,
        'installPath': installDir,
        'isInstalled': isInstalled,
        'size': size,
        'backupCount': backups.length,
        'hasWritePermission': await hasWritePermission(installDir),
      };

      LoggingService.debug('[macOS] Installation info: $info');
      return info;
    } catch (e) {
      LoggingService.error(
        '[macOS] Error getting installation info for channel: $channel',
        e,
      );
      return {
        'channel': channel,
        'installPath': '',
        'isInstalled': false,
        'size': 0,
        'backupCount': 0,
        'hasWritePermission': false,
      };
    }
  }
}
