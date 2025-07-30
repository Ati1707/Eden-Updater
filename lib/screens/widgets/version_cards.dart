import 'package:flutter/material.dart';
import '../../models/update_info.dart';
import '../../core/utils/url_launcher_utils.dart';
import '../../core/services/logging_service.dart';

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
    LoggingService.info('Attempting to launch URL: $url');
    // Capture context properties before async operations
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    try {
      final success = await UrlLauncherUtils.launchUrlRobust(url);

      if (!success) {
        // Fallback: copy URL to clipboard
        await UrlLauncherUtils.copyUrlToClipboard(url);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not open link. URL copied to clipboard.',
              style: TextStyle(color: theme.colorScheme.onInverseSurface),
            ),
            backgroundColor: theme.colorScheme.inverseSurface,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      LoggingService.error('Failed to launch URL: $url', e);

      // Show error message
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not open link or copy to clipboard.',
            style: TextStyle(color: theme.colorScheme.onError),
          ),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
