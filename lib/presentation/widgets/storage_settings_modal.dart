import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../providers/sync_provider.dart';
import '../../../core/config/google_oauth_config.dart';
import 'templates/standard_modal_template.dart';

/// Storage Settings Modal - Using StandardModalTemplate
class StorageSettingsModal extends StatefulWidget {
  const StorageSettingsModal({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: true,
      child: const StorageSettingsModal(),
    );
  }

  @override
  State<StorageSettingsModal> createState() => _StorageSettingsModalState();
}

class _StorageSettingsModalState extends State<StorageSettingsModal> {
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

  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return StandardModalTemplate.buildModalContainer(
          context: context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StandardModalTemplate.buildHeader(
                context: context,
                title: 'Cloud Storage',
                onCancel: () => Navigator.of(context).pop(),
                onOk: () => Navigator.of(context).pop(),
              ),
              StandardModalTemplate.buildContent(
                children: [
                  _buildSyncStatus(syncProvider),
                  const SizedBox(height: 8),
                  _buildGoogleDriveSection(syncProvider),
                  const SizedBox(height: 8),
                  _buildActionButtons(context, syncProvider),
                ],
              ),
            ],
          ),
        );
      },
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

    return StandardModalTemplate.buildInfoBox(
      icon: statusIcon,
      text: statusText,
      color: statusColor,
    );
  }

  Widget _buildGoogleDriveSection(SyncProvider syncProvider) {
    if (!_isPlatformSupported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Google Drive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StandardModalTemplate.buildInfoBox(
            icon: Icons.info_outline,
            text:
                'Desktop Setup Required\n\nGoogle Drive sync on Windows/Linux requires OAuth credentials. To enable this feature:\n\n1. Open lib/core/config/google_oauth_config.dart\n2. Follow the setup instructions in the file\n3. Add your Client ID and Client Secret',
            color: Colors.orange,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_outlined, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Google Drive',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (syncProvider.isSyncEnabled) ...[
          const Text(
            'Your NextChord data is being synced with Google Drive.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ] else ...[
          const Text(
            'Sign in with Google to enable cloud backup and sync across devices.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, SyncProvider syncProvider) {
    return Column(
      children: [
        if (syncProvider.isSyncEnabled)
          StandardModalTemplate.buildButton(
            label: syncProvider.isSyncing ? 'Syncing...' : 'Sync Now',
            icon: Icons.sync,
            onPressed: syncProvider.isSyncing
                ? null
                : () {
                    syncProvider.sync();
                  },
          ),
        if (syncProvider.isSyncEnabled) const SizedBox(height: 8),
        if (_isPlatformSupported && !syncProvider.isSyncEnabled)
          StandardModalTemplate.buildButton(
            label: 'Sign In',
            icon: Icons.login,
            onPressed: () {
              _handleSignIn(syncProvider);
            },
          ),
        if (!syncProvider.isSyncEnabled) const SizedBox(height: 8),
        if (_isPlatformSupported && syncProvider.isSyncEnabled)
          StandardModalTemplate.buildButton(
            label: 'Resync from Cloud',
            icon: Icons.cloud_download,
            onPressed: _isRestoring || syncProvider.isSyncing
                ? null
                : () {
                    _handleResyncFromCloud(context, syncProvider);
                  },
          ),
        if (_isPlatformSupported && syncProvider.isSyncEnabled)
          const SizedBox(height: 8),
        if (_isPlatformSupported && syncProvider.isSyncEnabled)
          StandardModalTemplate.buildButton(
            label: 'Sign Out',
            icon: Icons.logout,
            onPressed: () {
              _handleSignOut(syncProvider);
            },
          ),
        if (syncProvider.isSyncEnabled) const SizedBox(height: 8),
        StandardModalTemplate.buildButton(
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

  Future<void> _handleResyncFromCloud(
      BuildContext context, SyncProvider syncProvider) async {
    try {
      // Check if cloud backup exists first
      final hasBackup = await syncProvider.hasCloudBackup();
      if (!hasBackup) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cloud backup available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Restore from Cloud Backup'),
          content: const Text(
            'This will replace the local NextChord database with the backup stored in the cloud. Any unsynced local changes may be lost. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Set restoring state
      setState(() {
        _isRestoring = true;
      });

      // Perform restore
      final success = await syncProvider.restoreFromCloudBackup();

      if (context.mounted) {
        if (success) {
          // Show restart dialog
          final restartConfirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Database Restored'),
              content: const Text(
                'Your database has been successfully restored from the cloud backup. The app needs to restart to apply the changes.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Restart Now'),
                ),
              ],
            ),
          );

          if (restartConfirmed == true) {
            // Exit the app to force restart
            if (!kIsWeb) {
              exit(0);
            } else {
              // On web, just show success message since we can't restart
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Database restored successfully. Please refresh the page.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restore failed: ${syncProvider.lastError}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Reset restoring state
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
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
