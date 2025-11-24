import 'package:flutter/material.dart';
import '../../core/utils/device_breakpoints.dart';

/// Bottom floating search bar for phone mode (Safari-style)
class BottomSearchBar extends StatefulWidget {
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool isVisible;

  const BottomSearchBar({
    Key? key,
    required this.hintText,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<BottomSearchBar> createState() => _BottomSearchBarState();
}

class _BottomSearchBarState extends State<BottomSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(BottomSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!DeviceBreakpoints.isPhone(context)) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Colors.black.withValues(alpha: 0.4),
                fontSize: 16,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.black54,
                size: 20,
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.black54,
                        size: 20,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onClear?.call();
                        widget.onChanged?.call('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that adds bottom search bar to phone screens
/// while keeping existing sidebar content intact on desktop/tablet
class ResponsiveSearchWrapper extends StatelessWidget {
  final Widget child;
  final String searchHintText;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;
  final bool showSearchBar;

  const ResponsiveSearchWrapper({
    Key? key,
    required this.child,
    required this.searchHintText,
    required this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
    this.showSearchBar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPhone = DeviceBreakpoints.isPhone(context);

    if (!isPhone) {
      // Desktop/Tablet: return child as-is
      return child;
    }

    // Phone: wrap with bottom search bar (no Scaffold to avoid double scaffolding)
    return Stack(
      children: [
        // Main content
        child,

        // Bottom search bar overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BottomSearchBar(
            hintText: searchHintText,
            controller: searchController,
            onChanged: onSearchChanged,
            onClear: onSearchClear,
            isVisible: showSearchBar,
          ),
        ),
      ],
    );
  }
}
