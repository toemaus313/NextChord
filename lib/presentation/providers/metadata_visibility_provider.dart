import 'package:flutter/material.dart';

/// Provider for managing metadata visibility in song editor and viewer
/// Handles manual toggle state and keyboard dismissal logic
class MetadataVisibilityProvider extends ChangeNotifier {
  bool _isManuallyHidden = false;

  bool get isManuallyHidden => _isManuallyHidden;

  /// Check if user has hardware keyboard attached
  bool hasHardwareKeyboard(BuildContext context, FocusNode bodyFocusNode) {
    // Hardware keyboard is present when body is focused but no keyboard insets
    return bodyFocusNode.hasFocus &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
  }

  /// Toggle metadata visibility with complex behavior based on keyboard type
  void toggleWithKeyboardHandling(
    BuildContext context,
    FocusNode bodyFocusNode, {
    VoidCallback? onShowMetadata,
    VoidCallback? onHideMetadata,
  }) {
    final hasHardwareKb = hasHardwareKeyboard(context, bodyFocusNode);

    // Simply toggle the state
    _isManuallyHidden = !_isManuallyHidden;

    if (_isManuallyHidden) {
      // Now hidden - handle keyboard based on hardware presence
      if (!hasHardwareKb) {
        // No hardware keyboard - show on-screen keyboard
        bodyFocusNode.requestFocus();
      }
      onHideMetadata?.call();
    } else {
      // Now shown - always dismiss keyboard
      bodyFocusNode.unfocus();
      onShowMetadata?.call();
    }

    notifyListeners();
  }

  /// Simple toggle for cases where keyboard handling is not needed
  void toggle() {
    _isManuallyHidden = !_isManuallyHidden;
    notifyListeners();
  }

  /// Show metadata and dismiss keyboard if it's open
  void showWithKeyboardDismiss(BuildContext context, FocusNode bodyFocusNode) {
    if (_isManuallyHidden) {
      // Dismiss keyboard if it's open
      if (MediaQuery.viewInsetsOf(context).bottom > 0) {
        bodyFocusNode.unfocus();
      }
      _isManuallyHidden = false;
      notifyListeners();
    }
  }

  /// Reset to visible state (useful when switching between songs)
  void reset() {
    _isManuallyHidden = false;
    notifyListeners();
  }
}
