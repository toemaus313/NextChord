import 'dart:ui';
import 'package:flutter/material.dart';

/// **Liquid Glass Button** - Glassmorphism style button inspired by iOS 26
///
/// Features:
/// - BackdropFilter with blur effect (sigmaX/Y: 24)
/// - Semi-transparent gradient with reduced opacity for blue backgrounds
/// - Bright borders and soft shadows
/// - Press animations (scale and opacity)
/// - Fully customizable for different use cases
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsets padding;
  final bool enabled;
  final Color? tint;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 12,
    ),
    this.enabled = true,
    this.tint,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (widget.onPressed == null || !widget.enabled) return;

    if (value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Adjust gradient colors for blue gradient backgrounds
    // Increased opacity for more visible glass effect
    final gradientColors = widget.tint != null
        ? [
            widget.tint!.withValues(alpha: 0.4), // Increased from 0.25
            widget.tint!.withValues(alpha: 0.15), // Increased from 0.08
          ]
        : [
            Colors.white.withValues(alpha: 0.4), // Increased from 0.25
            Colors.white.withValues(alpha: 0.15), // Increased from 0.08
          ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        if (widget.enabled) {
          widget.onPressed?.call();
        }
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: widget.enabled ? _opacityAnimation.value : 0.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.8), // Increased from 0.6
                        width: 1.2, // Slightly thicker border
                      ),
                      boxShadow: [
                        // Soft outer shadow
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.4), // Increased from 0.3
                          blurRadius: 32, // Increased blur
                          offset: const Offset(0, 20), // Increased offset
                        ),
                        // Subtle top highlight
                        BoxShadow(
                          color: Colors.white
                              .withValues(alpha: 0.4), // Increased from 0.3
                          blurRadius: 10, // Increased blur
                          offset: const Offset(-2, -2),
                        ),
                      ],
                    ),
                    child: DefaultTextStyle.merge(
                      style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                      child: IconTheme.merge(
                        data: const IconThemeData(color: Colors.white),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// **Concise Liquid Glass Button** - Optimized for compact modal use
class ConciseLiquidGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final Color? tint;
  final double? width;

  const ConciseLiquidGlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.enabled = true,
    this.tint,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );

    if (width != null) {
      child = SizedBox(width: width!, child: child);
    } else {
      child = SizedBox(width: double.infinity, child: child);
    }

    return LiquidGlassButton(
      onPressed: onPressed,
      enabled: enabled,
      borderRadius: 8, // Smaller radius for compact design
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      tint: tint,
      child: child,
    );
  }
}
