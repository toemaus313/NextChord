import 'package:flutter/material.dart';
import 'bottom_search_bar.dart';

/// Responsive search wrapper that shows bottom search bar on phones
/// and embedded search on desktop/tablet
class ResponsiveSearchWrapper extends StatelessWidget {
  final String searchHintText;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;
  final bool showSearchBar;
  final Widget child;

  const ResponsiveSearchWrapper({
    Key? key,
    required this.searchHintText,
    required this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
    required this.showSearchBar,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (showSearchBar) {
      // Phone mode: Show bottom search bar overlay
      return Stack(
        children: [
          // Main content
          child,
          // Bottom search bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BottomSearchBar(
              hintText: searchHintText,
              controller: searchController,
              onChanged: onSearchChanged,
              onClear: onSearchClear,
              isVisible: true,
            ),
          ),
        ],
      );
    } else {
      // Desktop/Tablet mode: Return child as-is (embedded search handled by caller)
      return child;
    }
  }
}
