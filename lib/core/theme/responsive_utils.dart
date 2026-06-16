import 'package:flutter/material.dart';

enum ScreenBreakpoint { mobile, tablet, desktop }

class ResponsiveUtils {
  ResponsiveUtils._();

  static ScreenBreakpoint breakpoint(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return ScreenBreakpoint.mobile;
    if (w < 900) return ScreenBreakpoint.tablet;
    return ScreenBreakpoint.desktop;
  }

  static bool isMobile(BuildContext context) => breakpoint(context) == ScreenBreakpoint.mobile;
  static bool isTablet(BuildContext context) => breakpoint(context) == ScreenBreakpoint.tablet;
  static bool isDesktop(BuildContext context) => breakpoint(context) == ScreenBreakpoint.desktop;

  static double paddingValue(BuildContext context) {
    switch (breakpoint(context)) {
      case ScreenBreakpoint.mobile:
        return 16;
      case ScreenBreakpoint.tablet:
        return 24;
      case ScreenBreakpoint.desktop:
        return 32;
    }
  }

  static EdgeInsets padding(BuildContext context) {
    final v = paddingValue(context);
    return EdgeInsets.symmetric(horizontal: v, vertical: v * 0.5);
  }

  static EdgeInsets horizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: paddingValue(context));
  }

  static double maxContentWidth(BuildContext context) {
    switch (breakpoint(context)) {
      case ScreenBreakpoint.mobile:
        return double.infinity;
      case ScreenBreakpoint.tablet:
        return 600;
      case ScreenBreakpoint.desktop:
        return 900;
    }
  }

  static double gridColumns(BuildContext context) {
    switch (breakpoint(context)) {
      case ScreenBreakpoint.mobile:
        return 1;
      case ScreenBreakpoint.tablet:
        return 2;
      case ScreenBreakpoint.desktop:
        return 3;
    }
  }

  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenBreakpoint breakpoint) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => builder(context, ResponsiveUtils.breakpoint(context)),
      );
}

class ResponsivePadding extends StatelessWidget {
  final Widget child;

  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: ResponsiveUtils.padding(context),
        child: child,
      );
}


