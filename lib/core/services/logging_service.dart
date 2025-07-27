import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Centralized logging service for the Eden Updater application
/// Provides structured logging with file output for debugging and error tracking
class LoggingService {
  static LoggingService? _instance;
  static Logger? _logger;
  static File? _logFile;

  LoggingService._();

  /// Get the singleton instance of LoggingService
  static LoggingService get instance {
    _instance ??= LoggingService._();
    return _instance!;
  }

  /// Initialize the logging service
  /// Should be called early in the application lifecycle
  static Future<void> initialize() async {
    if (_logger != null) return; // Already initialized

    try {
      Directory logsDir;

      if (Platform.isAndroid) {
        // On Android, use external storage if available, otherwise internal
        Directory appDir;
        try {
          appDir =
              await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        } catch (e) {
          appDir = await getApplicationDocumentsDirectory();
        }
        logsDir = Directory(path.join(appDir.path, 'eden_updater_logs'));
      } else {
        // On Windows/Linux, use a logs folder next to the executable
        final executablePath = Platform.resolvedExecutable;
        final executableDir = path.dirname(executablePath);
        logsDir = Directory(path.join(executableDir, 'logs'));
      }

      await logsDir.create(recursive: true);

      // Create log file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File(path.join(logsDir.path, 'eden_updater_$timestamp.log'));

      // Create logger with custom output
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: false, // Disable colors for file output
          printEmojis: false,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        output: MultiOutput([
          ConsoleOutput(), // Still log to console for debugging
          FileOutput(file: _logFile!), // Log to file for persistence
        ]),
        level: Level.debug, // Log everything in debug builds
      );

      // Log initialization
      _logger!.i('Eden Updater logging initialized');
      _logger!.i('Platform: ${Platform.operatingSystem}');
      _logger!.i('Log file: ${_logFile!.path}');

      // Clean up old log files (keep only last 10)
      await _cleanupOldLogs(logsDir);
    } catch (e) {
      // Fallback to console-only logging if file logging fails

      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        level: Level.debug,
      );
      _logger!.w('Failed to initialize file logging, using console only: $e');
    }
  }

  /// Clean up old log files, keeping only the most recent ones
  static Future<void> _cleanupOldLogs(Directory logsDir) async {
    try {
      final logFiles = await logsDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                entity.path.endsWith('.log') &&
                path.basename(entity.path).startsWith('eden_updater_'),
          )
          .cast<File>()
          .toList();

      // Sort by modification time (newest first)
      logFiles.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      // Delete old files (keep only 10 most recent)
      if (logFiles.length > 10) {
        for (int i = 10; i < logFiles.length; i++) {
          try {
            await logFiles[i].delete();
          } catch (e) {
            // Ignore deletion errors
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Log debug message
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal error message
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.f(message, error: error, stackTrace: stackTrace);
  }

  /// Get the current log file path (if available)
  static String? get logFilePath => _logFile?.path;

  /// Get logs directory path
  static Future<String?> getLogsDirectory() async {
    try {
      if (Platform.isAndroid) {
        Directory appDir;
        try {
          appDir =
              await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        } catch (e) {
          appDir = await getApplicationDocumentsDirectory();
        }
        return path.join(appDir.path, 'eden_updater_logs');
      } else {
        // On Windows/Linux, use logs folder next to executable
        final executablePath = Platform.resolvedExecutable;
        final executableDir = path.dirname(executablePath);
        return path.join(executableDir, 'logs');
      }
    } catch (e) {
      return null;
    }
  }

  /// Get list of available log files
  static Future<List<File>> getLogFiles() async {
    try {
      final logsDir = await getLogsDirectory();
      if (logsDir == null) return [];

      final dir = Directory(logsDir);
      if (!await dir.exists()) return [];

      return await dir
          .list()
          .where(
            (entity) =>
                entity is File &&
                entity.path.endsWith('.log') &&
                path.basename(entity.path).startsWith('eden_updater_'),
          )
          .cast<File>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}

/// Custom file output for logger
class FileOutput extends LogOutput {
  final File file;

  FileOutput({required this.file});

  @override
  void output(OutputEvent event) {
    try {
      final buffer = StringBuffer();
      for (final line in event.lines) {
        buffer.writeln(line);
      }
      file.writeAsStringSync(buffer.toString(), mode: FileMode.append);
    } catch (e) {
      // Debug: print file write errors
    }
  }
}
