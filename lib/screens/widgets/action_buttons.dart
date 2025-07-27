import 'package:flutter/material.dart';

/// Widget containing the main action buttons for the updater
class ActionButtons extends StatelessWidget {
  final bool isChecking;
  final bool isDownloading;
  final bool isNotInstalled;
  final bool hasUpdate;
  final bool canDownload;
  final VoidCallback onCheckForUpdates;
  final VoidCallback? onDownloadUpdate;
  final VoidCallback? onLaunchEden;

  const ActionButtons({
    super.key,
    required this.isChecking,
    required this.isDownloading,
    required this.isNotInstalled,
    required this.hasUpdate,
    required this.canDownload,
    required this.onCheckForUpdates,
    this.onDownloadUpdate,
    this.onLaunchEden,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Hide buttons during download
    if (isDownloading) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Check for updates button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isChecking ? null : onCheckForUpdates,
            icon: isChecking
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(isChecking ? 'Checking...' : 'Check for Updates'),
          ),
        ),

        const SizedBox(width: 12),

        // Primary action button (Install/Update/Launch)
        Expanded(child: _buildPrimaryActionButton(theme)),
      ],
    );
  }

  Widget _buildPrimaryActionButton(ThemeData theme) {
    if (isNotInstalled || hasUpdate) {
      // Install or Update button
      return FilledButton.icon(
        onPressed: canDownload ? onDownloadUpdate : null,
        icon: const Icon(Icons.download),
        label: Text(isNotInstalled ? 'Install Eden' : 'Update Eden'),
      );
    } else {
      // Launch button
      return OutlinedButton.icon(
        onPressed: isChecking ? null : onLaunchEden,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Launch Eden'),
      );
    }
  }
}
