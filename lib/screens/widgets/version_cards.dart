import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../../models/update_info.dart';

/// Widget displaying current and latest version information
class VersionCards extends StatelessWidget {
  final UpdateInfo? currentVersion;
  final UpdateInfo? latestVersion;

  const VersionCards({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate =
        latestVersion != null &&
        currentVersion != null &&
        latestVersion!.version != currentVersion!.version;

    return Row(
      children: [
        Expanded(
          child: _VersionCard(
            title: 'Current',
            version: currentVersion?.version ?? 'Unknown',
            icon: Icons.phone_android,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _VersionCard(
            title: 'Latest',
            version: latestVersion?.version ?? 'Checking...',
            icon: hasUpdate ? Icons.new_releases : Icons.check_circle,
            color: hasUpdate
                ? theme.colorScheme.secondary
                : theme.colorScheme.tertiary,
            releaseUrl: hasUpdate ? latestVersion?.releaseUrl : null,
          ),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String title;
  final String version;
  final IconData icon;
  final Color color;
  final String? releaseUrl;

  const _VersionCard({
    required this.title,
    required this.version,
    required this.icon,
    required this.color,
    this.releaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReleaseUrl = releaseUrl != null && releaseUrl!.isNotEmpty;

    Widget cardContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasReleaseUrl) ...[
                const Spacer(),
                Icon(
                  Icons.open_in_new,
                  color: color.withValues(alpha: 0.7),
                  size: 16,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            version,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasReleaseUrl) ...[
            const SizedBox(height: 8),
            Text(
              'View changelog',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    if (hasReleaseUrl) {
      return InkWell(
        onTap: () => _launchUrl(context, releaseUrl!),
        borderRadius: BorderRadius.circular(20),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    // Capture context properties before async operations
    final messenger = ScaffoldMessenger.of(context);
    final mounted = context.mounted;

    if (!mounted) return;

    try {
      final uri = Uri.parse(url);

      // Try different launch modes for better Android compatibility
      bool launched = false;

      // Method 1: Try external application mode
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
        }
      } catch (e) {
        // Continue to next method
      }

      // Method 2: Try platform default mode
      if (!launched) {
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          launched = true;
        } catch (e) {
          // Continue to next method
        }
      }

      // Method 3: Try in-app web view mode (will fallback to external browser)
      if (!launched) {
        try {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
          launched = true;
        } catch (e) {
          // Continue to next method
        }
      }

      // Method 4: Android Intent fallback
      if (!launched && Platform.isAndroid) {
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: url,
            flags: <int>[0x10000000], // FLAG_ACTIVITY_NEW_TASK
          );
          await intent.launch();
          launched = true;
        } catch (e) {
          // Final fallback failed
        }
      }

      if (!launched) {
        // Show error message to user
        _showUrlErrorSafe(messenger, url);
      }
    } catch (e) {
      _showUrlErrorSafe(messenger, url);
    }
  }

  void _showUrlErrorSafe(ScaffoldMessengerState messenger, String url) {
    // Show error message to user using captured messenger
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not open link. Please visit: $url'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // Copy URL to clipboard as fallback
            Clipboard.setData(ClipboardData(text: url));
            messenger.showSnackBar(
              const SnackBar(
                content: Text('URL copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}
