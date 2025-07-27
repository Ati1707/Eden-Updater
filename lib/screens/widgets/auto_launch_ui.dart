import 'package:flutter/material.dart';
import '../../core/enums/app_enums.dart';
import 'nightly_warning.dart';

/// Widget displayed during auto-launch mode
class AutoLaunchUI extends StatelessWidget {
  final bool isDownloading;
  final double downloadProgress;
  final ReleaseChannel releaseChannel;

  const AutoLaunchUI({
    super.key,
    required this.isDownloading,
    required this.downloadProgress,
    required this.releaseChannel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface,
              theme.colorScheme.primary.withValues(alpha: 0.1),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(theme),
              const SizedBox(height: 24),
              _buildTitle(theme),
              const SizedBox(height: 16),
              _buildProgressIndicator(theme),
              if (releaseChannel == ReleaseChannel.nightly) ...[
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: NightlyWarning(isAutoLaunch: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.videogame_asset, color: Colors.white, size: 40),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Text(
      'Eden Launcher',
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    if (isDownloading) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: downloadProgress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            '${(downloadProgress * 100).toInt()}% Complete',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    } else {
      return const CircularProgressIndicator();
    }
  }
}
