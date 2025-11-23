import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../core/config/google_oauth_config.dart';
import 'templates/concise_modal_template.dart';

/// **Concise Modal Template Implementation** - Storage Settings
///
/// This demonstrates how to use the ConciseModalTemplate for consistent,
/// compact modal design across the application.
class StorageSettingsModal extends StatefulWidget {
  const StorageSettingsModal({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    return ConciseModalTemplate.showConciseModal<void>(
      context: context,
      barrierDismissible: true,
      child: const StorageSettingsModal(),
    );
  }

  @override
  State<StorageSettingsModal> createState() => _StorageSettingsModalState();
}

class _StorageSettingsModalState extends State<StorageSettingsModal>
    with ConciseModalContentMixin {
  bool get _isPlatformSupported {
    if (kIsWeb) return true;

    // Mobile platforms (iOS, Android) and macOS are supported
    final isMobileOrMac = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // Desktop platforms (Windows, Linux, macOS) need OAuth config
    final isDesktopWithConfig =
        (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.macOS) &&
            GoogleOAuthConfig.isConfigured;

    return isMobileOrMac || isDesktopWithConfig;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            buildConciseContent(
              children: addConciseSpacing([
                _buildSyncStatus(syncProvider),
                _buildGoogleDriveSection(syncProvider),
                _buildActionButtons(context, syncProvider),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ConciseModalTemplate.buildConciseHeader(
      context: context,
      title: 'Cloud Storage',
      onCancel: () => Navigator.of(context).pop(),
      onOk: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildSyncStatus(SyncProvider syncProvider) {
    String statusText;
    IconData statusIcon;
    Color statusColor = Colors.white70;

    if (syncProvider.isSyncing) {
      statusText = 'Syncing...';
      statusIcon = Icons.sync;
    } else if (syncProvider.lastSyncTime != null) {
      statusText =
          'Last synced: ${_formatLastSync(syncProvider.lastSyncTime!)}';
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green[200]!;
    } else if (syncProvider.lastError != null) {
      statusText = 'Sync error: ${syncProvider.lastError}';
      statusIcon = Icons.error_outline;
      statusColor = Colors.orange[300]!;
    } else {
      statusText = 'Not synced yet';
      statusIcon = Icons.cloud_off;
    }

    return ConciseModalTemplate.buildConciseInfoBox(
      icon: statusIcon,
      text: statusText,
      color: statusColor,
    );
  }

  Widget _buildGoogleDriveSection(SyncProvider syncProvider) {
    if (!_isPlatformSupported) {
      return ConciseModalTemplate.buildConciseSettingColumn(
        icon: Icons.cloud_off,
        label: 'Google Drive',
        children: [
          ConciseModalTemplate.buildConciseInfoBox(
            icon: Icons.info_outline,
            text:
                'Desktop Setup Required\n\nGoogle Drive sync on Windows/Linux requires OAuth credentials. To enable this feature:\n\n1. Open lib/core/config/google_oauth_config.dart\n2. Follow the setup instructions in the file\n3. Add your Client ID and Client Secret',
            color: Colors.orange,
          ),
        ],
      );
    }

    return ConciseModalTemplate.buildConciseSettingColumn(
      icon: Icons.cloud_outlined,
      label: 'Google Drive',
      children: [
        if (syncProvider.isSyncEnabled) ...[
          Text(
            'Your NextChord data is being synced with Google Drive.',
            style: ConciseModalTemplate.secondaryTextStyle,
          ),
        ] else ...[
          Text(
            'Sign in with Google to enable cloud backup and sync across devices.',
            style: ConciseModalTemplate.secondaryTextStyle,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, SyncProvider syncProvider) {
    return Column(
      children: [
        if (syncProvider.isSyncEnabled)
          ConciseModalTemplate.buildConciseButton(
            label: syncProvider.isSyncing ? 'Syncing...' : 'Sync Now',
            icon: Icons.sync,
            enabled: !syncProvider.isSyncing,
            onPressed: syncProvider.isSyncing
                ? null
                : () {
                    syncProvider.sync();
                  },
          ),
        if (_isPlatformSupported && !syncProvider.isSyncEnabled)
          ConciseModalTemplate.buildConciseButton(
            label: 'Sign In',
            icon: Icons.login,
            onPressed: () {
              _handleSignIn(syncProvider);
            },
          ),
        if (_isPlatformSupported && syncProvider.isSyncEnabled)
          ConciseModalTemplate.buildConciseButton(
            label: 'Sign Out',
            icon: Icons.logout,
            onPressed: () {
              _handleSignOut(syncProvider);
            },
          ),
        ConciseModalTemplate.buildConciseButton(
          label: 'Close',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _handleSignIn(SyncProvider syncProvider) async {
    try {
      await syncProvider.signIn();
    } catch (e) {}
  }

  Future<void> _handleSignOut(SyncProvider syncProvider) async {
    try {
      await syncProvider.signOut();
    } catch (e) {}
  }

  String _formatLastSync(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
