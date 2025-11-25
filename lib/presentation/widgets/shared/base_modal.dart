import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Base modal template with consistent NextChord styling
///
/// This eliminates duplication across 8+ modal files and ensures
/// consistent gradient styling, borders, and layout patterns.
class BaseModal extends StatelessWidget {
  final Widget title;
  final List<Widget> actions;
  final Widget content;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsets? insetPadding;
  final bool showHeader;

  const BaseModal({
    Key? key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.maxWidth = 480,
    this.maxHeight = 650,
    this.insetPadding,
    this.showHeader = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.modalBackground,
      insetPadding: insetPadding ?? const EdgeInsets.all(24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? double.infinity,
          maxHeight: maxHeight ?? double.infinity,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gradientStart,
              AppColors.gradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader) _buildHeader(),
            Flexible(child: content),
            if (actions.isNotEmpty) _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.modalBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left action (typically Cancel)
          if (actions.isNotEmpty) actions.first,
          // Centered title
          Expanded(
            child: Center(
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                child: title,
              ),
            ),
          ),
          // Right action (typically Save/Confirm)
          if (actions.length > 1) actions[1],
          if (actions.length == 1)
            const SizedBox(width: 80), // Balance the layout
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.modalBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ...actions.map((action) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: action,
              )),
        ],
      ),
    );
  }
}

/// Standard styled button for NextChord modals
class ModalButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const ModalButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;

    if (isDestructive) {
      backgroundColor = AppColors.error.withOpacity(0.2);
      foregroundColor = AppColors.error;
    } else if (isPrimary) {
      backgroundColor = AppColors.interactiveDisabled;
      foregroundColor = AppColors.textPrimary;
    } else {
      backgroundColor = AppColors.interactiveDisabled;
      foregroundColor = AppColors.textPrimary;
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

/// Standard styled container for modal content sections
class ModalSection extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool showBorder;

  const ModalSection({
    Key? key,
    required this.child,
    this.padding,
    this.showBorder = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: showBorder
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
            )
          : null,
      child: child,
    );
  }
}
