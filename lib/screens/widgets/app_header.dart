import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/platform/platform_factory.dart';
import '../../core/utils/url_launcher_utils.dart';
import 'logs_dialog.dart';

/// Header widget for the updater screen
class AppHeader extends StatelessWidget {
  final String releaseChannel;
  final Function(String)? onTestVersion;

  const AppHeader({
    super.key,
    required this.releaseChannel,
    this.onTestVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.videogame_asset,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eden Updater',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your Eden emulator up to date',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (kDebugMode && onTestVersion != null)
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => _showVersionDialog(context),
                    icon: Icon(Icons.edit, color: theme.colorScheme.tertiary),
                    tooltip: 'Set Version (Debug)',
                  ),
                ),
              if (kDebugMode && onTestVersion != null)
                const SizedBox(height: 8),
              // Logs button (visible on Android for debugging)
              if (PlatformFactory.getCurrentPlatformConfig().name ==
                  'Android') ...[
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => _showLogsDialog(context),
                    icon: Icon(
                      Icons.description,
                      color: theme.colorScheme.secondary,
                    ),
                    tooltip: 'View Logs',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _openGitHub(context, releaseChannel),
                  icon: Icon(
                    Icons.open_in_new,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Open GitHub',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openGitHub(BuildContext context, String channel) async {
    final url = channel == AppConstants.nightlyChannel
        ? 'https://github.com/pflyly/eden-nightly/releases'
        : 'https://github.com/eden-emulator/Releases/releases';

    final success = await UrlLauncherUtils.launchUrlRobust(url);
    if (!success) {
      // Fallback: copy URL to clipboard and show feedback
      await UrlLauncherUtils.copyUrlToClipboard(url);

      // Show snackbar to inform user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not open browser. GitHub URL copied to clipboard.',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          ),
        );
      }
    }
  }

  void _showLogsDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const LogsDialog());
  }

  void _showVersionDialog(BuildContext context) {
    final controller = TextEditingController(text: 'v1.0.0-test');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Test Version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a version string for testing:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Version',
                hintText: 'e.g., v1.0.0-test',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final version = controller.text.trim();
              if (version.isNotEmpty && onTestVersion != null) {
                Navigator.of(context).pop();
                onTestVersion!(version);
              }
            },
            child: const Text('Set Version'),
          ),
        ],
      ),
    );
  }
}
