import 'package:flutter/material.dart';
import '../core/enums/app_enums.dart';
import 'controllers/updater_controller.dart';
import 'state/updater_state.dart';
import 'widgets/app_header.dart';
import 'widgets/channel_selector.dart';
import 'widgets/version_cards.dart';
import 'widgets/download_progress.dart';
import 'widgets/action_buttons.dart';
import 'widgets/settings_section.dart';
import 'widgets/auto_launch_ui.dart';
import 'widgets/nightly_warning.dart';

/// Main updater screen with clean, modular architecture
class UpdaterScreen extends StatefulWidget {
  final bool isAutoLaunch;
  final String? channel;

  const UpdaterScreen({super.key, this.isAutoLaunch = false, this.channel});

  @override
  State<UpdaterScreen> createState() => _UpdaterScreenState();
}

class _UpdaterScreenState extends State<UpdaterScreen> {
  late UpdaterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UpdaterController(onStateChanged: () => setState(() {}));
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _controller.initialize(channel: widget.channel);

    if (widget.isAutoLaunch) {
      await _controller.performAutoLaunchSequence();
    } else {
      await _controller.checkForUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    // Show auto-launch UI if in auto-launch mode
    if (widget.isAutoLaunch && state.autoLaunchInProgress) {
      return AutoLaunchUI(
        isDownloading: state.isDownloading,
        downloadProgress: state.downloadProgress,
        releaseChannel: state.releaseChannel,
      );
    }

    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildMainContent(context, state),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
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
    );
  }

  Widget _buildMainContent(BuildContext context, state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildHeader(state),
                  const SizedBox(height: 24),
                  if (state.releaseChannel == ReleaseChannel.nightly)
                    _buildNightlyWarning(state),
                  _buildChannelSelector(state),
                  const SizedBox(height: 24),
                  _buildVersionCards(state),
                  const SizedBox(height: 24),
                  _buildActionsSection(context, state),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(UpdaterState state) {
    return AppHeader(
      releaseChannel: state.releaseChannel.value,
      onTestVersion: (version) => _controller.setTestVersion(version),
    );
  }

  Widget _buildChannelSelector(UpdaterState state) {
    return ChannelSelector(
      selectedChannel: state.releaseChannel.value,
      isEnabled: !state.isOperationInProgress,
      onChannelChanged: (value) {
        if (value != null) {
          final channel = ReleaseChannel.fromString(value);
          _controller.changeReleaseChannel(channel);
        }
      },
    );
  }

  Widget _buildVersionCards(UpdaterState state) {
    return VersionCards(
      currentVersion: state.currentVersion,
      latestVersion: state.latestVersion,
    );
  }

  Widget _buildNightlyWarning(UpdaterState state) {
    return Column(children: [NightlyWarning(), const SizedBox(height: 24)]);
  }

  Widget _buildActionsSection(BuildContext context, state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Download progress (shown during download)
          if (state.isDownloading) ...[
            DownloadProgress(progress: state.downloadProgress),
            const SizedBox(height: 24),
          ],

          // Settings section
          SettingsSection(
            createShortcuts: state.createShortcuts,
            portableMode: state.portableMode,
            isEnabled: !state.isOperationInProgress,
            onCreateShortcutsChanged: _controller.updateCreateShortcuts,
            onPortableModeChanged: _controller.updatePortableMode,
          ),

          const SizedBox(height: 16),

          // Action buttons
          ActionButtons(
            isChecking: state.isChecking,
            isDownloading: state.isDownloading,
            isNotInstalled: state.isNotInstalled,
            hasUpdate: state.hasUpdate,
            canDownload: state.canStartOperation && state.latestVersion != null,
            onCheckForUpdates: () => _handleCheckForUpdates(context),
            onDownloadUpdate: state.latestVersion != null
                ? _handleDownloadUpdate
                : null,
            onLaunchEden: state.canStartOperation
                ? _controller.launchEden
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckForUpdates(BuildContext context) async {
    // Capture context values before async call
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    try {
      await _controller.checkForUpdates(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadUpdate() async {
    // Capture context values before async call
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    try {
      await _controller.downloadUpdate();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }
}
