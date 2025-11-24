import 'package:flutter/material.dart';
import 'mobile_sidebar_header.dart';

/// Mobile sidebar scaffold that provides consistent header + content layout
class MobileSidebarScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;
  final Widget body;

  const MobileSidebarScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.actions,
    this.leading,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MobileSidebarHeader(
          title: title,
          icon: icon,
          actions: actions,
          leading: leading,
          onBack: onBack,
        ),
        Expanded(
          child: body,
        ),
      ],
    );
  }
}
