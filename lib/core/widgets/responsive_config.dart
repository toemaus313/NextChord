import 'package:flutter/material.dart';
import '../utils/device_breakpoints.dart';

/// Inherited widget that provides responsive configuration to descendant widgets
class ResponsiveConfig extends InheritedWidget {
  final bool isPhoneMode;
  final bool isTabletMode;
  final bool isDesktopMode;
  final FormFactor formFactor;

  const ResponsiveConfig({
    Key? key,
    required this.isPhoneMode,
    required this.isTabletMode,
    required this.isDesktopMode,
    required this.formFactor,
    required Widget child,
  }) : super(key: key, child: child);

  /// Create ResponsiveConfig from current BuildContext
  factory ResponsiveConfig.of(BuildContext context) {
    final formFactor = DeviceBreakpoints.getFormFactor(context);
    return ResponsiveConfig(
      isPhoneMode: DeviceBreakpoints.isPhone(context),
      isTabletMode: DeviceBreakpoints.isTablet(context),
      isDesktopMode: DeviceBreakpoints.isDesktop(context),
      formFactor: formFactor,
      child: const SizedBox.shrink(), // Dummy child for factory
    );
  }

  /// Get the nearest ResponsiveConfig from the widget tree
  static ResponsiveConfig? ofMaybe(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ResponsiveConfig>();
  }

  /// Convenience method to check if current device is phone
  static bool isPhone(BuildContext context) {
    final config = ofMaybe(context);
    return config?.isPhoneMode ?? DeviceBreakpoints.isPhone(context);
  }

  /// Convenience method to check if current device is tablet
  static bool isTablet(BuildContext context) {
    final config = ofMaybe(context);
    return config?.isTabletMode ?? DeviceBreakpoints.isTablet(context);
  }

  /// Convenience method to check if current device is desktop
  static bool isDesktop(BuildContext context) {
    final config = ofMaybe(context);
    return config?.isDesktopMode ?? DeviceBreakpoints.isDesktop(context);
  }

  /// Convenience method to get current form factor
  static FormFactor getFormFactor(BuildContext context) {
    final config = ofMaybe(context);
    return config?.formFactor ?? DeviceBreakpoints.getFormFactor(context);
  }

  @override
  bool updateShouldNotify(ResponsiveConfig oldWidget) {
    return isPhoneMode != oldWidget.isPhoneMode ||
        isTabletMode != oldWidget.isTabletMode ||
        isDesktopMode != oldWidget.isDesktopMode ||
        formFactor != oldWidget.formFactor;
  }
}

/// Widget that provides responsive configuration to its descendants
class ResponsiveConfigProvider extends StatelessWidget {
  final Widget child;

  const ResponsiveConfigProvider({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ResponsiveConfig(
          isPhoneMode: DeviceBreakpoints.isPhone(context),
          isTabletMode: DeviceBreakpoints.isTablet(context),
          isDesktopMode: DeviceBreakpoints.isDesktop(context),
          formFactor: DeviceBreakpoints.getFormFactor(context),
          child: child,
        );
      },
    );
  }
}
