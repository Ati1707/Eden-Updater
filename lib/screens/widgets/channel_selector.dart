import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Widget for selecting release channel
class ChannelSelector extends StatelessWidget {
  final String selectedChannel;
  final bool isEnabled;
  final ValueChanged<String?> onChannelChanged;

  const ChannelSelector({
    super.key,
    required this.selectedChannel,
    required this.isEnabled,
    required this.onChannelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get available channels based on platform
    final availableChannels = _getAvailableChannels();

    // If only one channel is available, show a simple info widget instead of dropdown
    if (availableChannels.length == 1) {
      return _buildSingleChannelInfo(context, theme, availableChannels.first);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                'Release Channel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedChannel,
                isDense: true,
                items: availableChannels
                    .map((channel) => _buildChannelItem(theme, channel))
                    .toList(),
                onChanged: isEnabled ? onChannelChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get available channels based on platform configuration
  List<String> _getAvailableChannels() {
    final channels = <String>[AppConstants.stableChannel];

    // Add nightly channel only if supported on current platform
    if (Platform.isAndroid) {
      if (AppConstants.androidSupportsNightly) {
        channels.add(AppConstants.nightlyChannel);
      }
    } else {
      // Desktop platforms support nightly
      channels.add(AppConstants.nightlyChannel);
    }

    return channels;
  }

  /// Build a single channel info widget when only one channel is available
  Widget _buildSingleChannelInfo(
    BuildContext context,
    ThemeData theme,
    String channel,
  ) {
    final isStable = channel == AppConstants.stableChannel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                'Release Channel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isStable ? Icons.verified : Icons.science,
                  size: 18,
                  color: isStable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  isStable ? 'Stable' : 'Nightly',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isStable
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                ),
                if (Platform.isAndroid && isStable) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a dropdown item for a channel
  DropdownMenuItem<String> _buildChannelItem(ThemeData theme, String channel) {
    final isStable = channel == AppConstants.stableChannel;

    return DropdownMenuItem(
      value: channel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStable ? Icons.verified : Icons.science,
            size: 18,
            color: isStable
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            isStable ? 'Stable' : 'Nightly',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isStable
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
