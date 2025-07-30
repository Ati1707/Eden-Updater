import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// A simple, lightweight logging service with log rotation.
class LoggingService {
  static IOSink? _logSink;
  static String? _logFilePath;
  static bool _initialized = false;
  static const int _maxLogFiles = 3;

  // Private constructor to prevent instantiation
  LoggingService._();

  /// Initializes the logging service.
  /// Call this once at application startup.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Use a "logs" subfolder within the app's documents directory.
      // On Android, this will be in the app's private external storage
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory(path.join(directory.path, 'Eden', 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Clean up old log files before creating a new one.
      await _cleanupOldLogs(logDir);

      // Create a new log file with the current date.
      final date = DateTime.now();
      final dateString =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}-${date.second.toString().padLeft(2, '0')}";
      _logFilePath = path.join(logDir.path, '$dateString.log');
      final logFile = File(_logFilePath!);

      _logSink = logFile.openWrite(mode: FileMode.append);
      _initialized = true;

      _log('INFO', '--- Logging Initialized ---');
      _log('INFO', 'Platform: ${Platform.operatingSystem} ${Platform.version}');
      _log('INFO', 'Log file: $_logFilePath');
    } catch (e) {
      // If file logging fails, fall back to console-only.
      _logSink = null;
    }
  }

  /// Clean up old log files, keeping only the most recent ones.
  static Future<void> _cleanupOldLogs(Directory logDir) async {
    try {
      // Use async list() and filter the stream.
      final logFiles = await logDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      // Sort by modification date, oldest first.
      logFiles.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );

      // If we are at or above the max number of files, delete the oldest ones.
      // We check for ">=" because we are about to create a new file.
      if (logFiles.length >= _maxLogFiles) {
        // We want to end up with (_maxLogFiles - 1) files before creating the new one.
        final filesToDeleteCount = logFiles.length - (_maxLogFiles - 1);
        for (int i = 0; i < filesToDeleteCount; i++) {
          await logFiles[i].delete();
        }
      }
    } catch (e) {
      // Ignore cleanup errors, not critical.
    }
  }

  /// Closes the log file sink. Good to call on app exit if possible.
  static Future<void> dispose() async {
    await _logSink?.flush();
    await _logSink?.close();
  }

  static void info(String message) => _log('INFO', message);
  static void debug(String message) => _log('DEBUG', message);
  static void warning(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) => _log('WARN', message, error, stackTrace);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log('ERROR', message, error, stackTrace);
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log('FATAL', message, error, stackTrace);

  /// Internal log handler.
  static void _log(
    String level,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] $message';

    // Always print to console for live debugging.

    // Write to the file sink if it's available.
    _logSink?.writeln(logMessage);

    if (error != null) {
      final errorMessage = '  Error: $error';
      _logSink?.writeln(errorMessage);
    }
    if (stackTrace != null) {
      final stackTraceMessage = '  Stack Trace:\n$stackTrace';
      _logSink?.writeln(stackTraceMessage);
    }
  }

  /// Gets a list of available log files, sorted newest first.
  static Future<List<File>> getLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory(path.join(directory.path, 'Eden', 'logs'));

      // Debug logging for Android troubleshooting
      print('[LoggingService] Documents directory: ${directory.path}');
      print('[LoggingService] Log directory: ${logDir.path}');
      print('[LoggingService] Log directory exists: ${await logDir.exists()}');

      if (!await logDir.exists()) {
        print(
          '[LoggingService] Log directory does not exist, returning empty list',
        );
        return [];
      }

      // List all files in the directory for debugging
      final allEntities = await logDir.list().toList();
      print(
        '[LoggingService] All entities in log directory: ${allEntities.map((e) => path.basename(e.path)).toList()}',
      );

      // Correctly filter the stream before collecting to a list.
      final files = await logDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      print(
        '[LoggingService] Found ${files.length} log files: ${files.map((f) => path.basename(f.path)).toList()}',
      );

      // Sort newest first for the UI.
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      return files;
    } catch (e) {
      print('[LoggingService] Error getting log files: $e');
      return [];
    }
  }

  /// Get the current log file path.
  static String? get logFilePath => _logFilePath;
}
