import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../core/config/google_oauth_config.dart';

class StorageSettingsModal extends StatefulWidget {
  const StorageSettingsModal({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480, minHeight: 550),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0468cc),
                    Color.fromARGB(150, 3, 73, 153),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: const StorageSettingsModal(),
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSyncStatus(syncProvider),
            const SizedBox(height: 16),
            _buildGoogleDriveSection(syncProvider),
            const SizedBox(height: 16),
            _buildActionButtons(context, syncProvider),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Cloud Storage',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
              ),
            ),
          ),
          if (syncProvider.isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleDriveSection(SyncProvider syncProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Google Drive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_isPlatformSupported)
                Switch(
                  value: syncProvider.isSyncEnabled,
                  onChanged: (value) async {
                    if (value) {
                      await _handleSignIn(syncProvider);
                    } else {
                      await _handleSignOut(syncProvider);
                    }
                  },
                  activeThumbColor: Colors.blue,
                  inactiveThumbColor: Colors.grey,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isPlatformSupported)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Desktop Setup Required',
                          style: TextStyle(
                            color: Colors.orange.shade200,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google Drive sync on Windows/Linux requires OAuth credentials. To enable this feature:\n\n1. Open lib/core/config/google_oauth_config.dart\n2. Follow the setup instructions in the file\n3. Add your Client ID and Client Secret',
                    style: TextStyle(
                      color: Colors.orange.shade100,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else if (syncProvider.isSyncEnabled) ...[
            const Text(
              'Your NextChord data is being synced with Google Drive.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ] else ...[
            const Text(
              'Sign in with Google to enable cloud backup and sync across devices.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SyncProvider syncProvider) {
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('Close'),
        ),
        const Spacer(),
        if (syncProvider.isSyncEnabled)
          TextButton.icon(
            onPressed: syncProvider.isSyncing
                ? null
                : () async {
                    try {
                      await syncProvider.sync();
                    } catch (e) {
                      debugPrint('Sync error: $e');
                    }
                  },
            icon: const Icon(Icons.sync, size: 18),
            label: Text(syncProvider.isSyncing ? 'Syncing...' : 'Sync Now'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleSignIn(SyncProvider syncProvider) async {
    try {
      await syncProvider.signIn();
    } catch (e) {
      debugPrint('Sign in error: $e');
    }
  }

  Future<void> _handleSignOut(SyncProvider syncProvider) async {
    try {
      await syncProvider.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
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
