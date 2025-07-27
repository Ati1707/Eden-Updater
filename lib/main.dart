import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/command_line_parser.dart';
import 'core/services/service_locator.dart';
import 'core/services/logging_service.dart';
import 'screens/updater_screen.dart';

void main(List<String> args) async {
  // Run app with error zone - ensure all initialization happens in the same zone
  runZonedGuarded(
    () async {
      // Ensure Flutter binding is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize logging first
      await LoggingService.initialize();
      LoggingService.info('Eden Updater starting with args: $args');

      // Set up global error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        LoggingService.fatal(
          'Flutter Error: ${details.exception}',
          details.exception,
          details.stack,
        );
      };

      // Handle errors outside of Flutter
      PlatformDispatcher.instance.onError = (error, stack) {
        LoggingService.fatal('Platform Error: $error', error, stack);
        return true;
      };

      // Initialize services
      ServiceLocator.initialize();

      final parser = CommandLineParser(args);
      LoggingService.info(
        'Parsed command line - Auto launch: ${parser.isAutoLaunch}, Channel: ${parser.channel}',
      );

      runApp(
        EdenUpdaterApp(
          isAutoLaunch: parser.isAutoLaunch,
          channel: parser.channel,
        ),
      );
    },
    (error, stack) {
      LoggingService.fatal('Unhandled Zone Error: $error', error, stack);
    },
  );
}

class EdenUpdaterApp extends StatelessWidget {
  final bool isAutoLaunch;
  final String? channel;

  const EdenUpdaterApp({super.key, this.isAutoLaunch = false, this.channel});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eden Updater',
      theme: AppTheme.darkTheme,
      home: UpdaterScreen(isAutoLaunch: isAutoLaunch, channel: channel),
      debugShowCheckedModeBanner: false,
    );
  }
}
