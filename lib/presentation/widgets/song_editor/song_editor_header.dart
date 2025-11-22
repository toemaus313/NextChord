import 'package:flutter/material.dart';

/// Header widget for song editor with title and action buttons
class SongEditorHeader extends StatelessWidget {
  final String title;
  final bool isEditing;
  final bool isSaving;
  final Color textColor;
  final Color actionColor;
  final bool isDarkMode;
  final VoidCallback onBackPressed;
  final VoidCallback onSavePressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onConvertPressed;
  final VoidCallback onImportFromUltimateGuitarPressed;
  final VoidCallback onImportFromFilePressed;
  final VoidCallback onToggleMetadata;
  final bool isMetadataHidden;

  const SongEditorHeader({
    super.key,
    required this.title,
    required this.isEditing,
    required this.isSaving,
    required this.textColor,
    required this.actionColor,
    required this.isDarkMode,
    required this.onBackPressed,
    required this.onSavePressed,
    required this.onDeletePressed,
    required this.onConvertPressed,
    required this.onImportFromUltimateGuitarPressed,
    required this.onImportFromFilePressed,
    required this.onToggleMetadata,
    required this.isMetadataHidden,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Header with title
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
            color: isDarkMode ? const Color(0xFF121212) : Colors.white,
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),

        // Back button (top left)
        Positioned(
          top: 8,
          left: 8,
          child: _buildActionButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: onBackPressed,
            color: textColor,
            isDarkMode: isDarkMode,
          ),
        ),

        // Convert button available in both create & edit modes
        Positioned(
          top: 8,
          right: 152,
          child: _buildActionButton(
            icon: Icons.auto_fix_high,
            tooltip: 'Convert to ChordPro',
            onPressed: onConvertPressed,
            color: actionColor,
            isDarkMode: isDarkMode,
          ),
        ),

        // Keyboard toggle button (top right)
        Positioned(
          top: 8,
          right: 104,
          child: _buildActionButton(
            icon: Icons.keyboard,
            tooltip: isMetadataHidden ? 'Show Metadata' : 'Hide Metadata',
            onPressed: onToggleMetadata,
            color: isMetadataHidden ? Colors.grey : actionColor,
            isDarkMode: isDarkMode,
          ),
        ),

        // Delete button (top right, only when editing)
        if (isEditing)
          Positioned(
            top: 8,
            right: 56,
            child: _buildActionButton(
              icon: Icons.delete,
              tooltip: 'Delete Song',
              onPressed: onDeletePressed,
              color: Colors.red,
              isDarkMode: isDarkMode,
            ),
          ),

        // Import buttons (top right, only when creating)
        if (!isEditing) ...[
          Positioned(
            top: 8,
            right: 104,
            child: _buildActionButton(
              icon: Icons.cloud_download,
              tooltip: 'Import from Ultimate Guitar',
              onPressed: onImportFromUltimateGuitarPressed,
              color: actionColor,
              isDarkMode: isDarkMode,
            ),
          ),
          Positioned(
            top: 8,
            right: 56,
            child: _buildActionButton(
              icon: Icons.file_upload,
              tooltip: 'Import from File',
              onPressed: onImportFromFilePressed,
              color: actionColor,
              isDarkMode: isDarkMode,
            ),
          ),
        ],

        // Save button (top right)
        Positioned(
          top: 8,
          right: 8,
          child: isSaving
              ? _buildLoadingButton()
              : _buildActionButton(
                  icon: Icons.save,
                  tooltip: 'Save',
                  onPressed: onSavePressed,
                  color: actionColor,
                  isDarkMode: isDarkMode,
                ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1.0,
        ),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color,
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1.0,
        ),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(actionColor),
          ),
        ),
      ),
    );
  }
}
