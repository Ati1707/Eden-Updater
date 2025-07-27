import 'dart:io';
import 'package:flutter/material.dart';

/// Widget for displaying and managing user settings/preferences
class SettingsSection extends StatelessWidget {
  final bool createShortcuts;
  final bool portableMode;
  final bool isEnabled;
  final ValueChanged<bool> onCreateShortcutsChanged;
  final ValueChanged<bool> onPortableModeChanged;

  const SettingsSection({
    super.key,
    required this.createShortcuts,
    required this.portableMode,
    required this.isEnabled,
    required this.onCreateShortcutsChanged,
    required this.onPortableModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Hide entire settings section on Android since no options are applicable
    if (Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Create shortcuts checkbox (Windows and Linux)
        _buildCheckboxRow(
          theme: theme,
          value: createShortcuts,
          label: 'Create desktop shortcut',
          onChanged: isEnabled ? onCreateShortcutsChanged : null,
        ),

        // Portable mode checkbox (Windows only)
        if (Platform.isWindows) ...[
          const SizedBox(height: 8),
          _buildCheckboxRow(
            theme: theme,
            value: portableMode,
            label: 'Portable mode (creates user folder where the eden.exe is)',
            onChanged: isEnabled ? onPortableModeChanged : null,
          ),
        ],
      ],
    );
  }

  Widget _buildCheckboxRow({
    required ThemeData theme,
    required bool value,
    required String label,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged != null
              ? (val) => onChanged(val ?? false)
              : null,
          activeColor: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
