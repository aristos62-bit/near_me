import 'package:flutter/material.dart';
import '../debug/debug_config.dart';

enum ScreenBreakpoint { mobile, tablet, desktop }

class ResponsiveUtils {
  ResponsiveUtils._();

  // ─────────────────────────────────────────────────────────────
  // SINGLE RESOLVER — constraints έχουν προτεραιότητα,
  // MediaQuery fallback όταν constraints δεν είναι διαθέσιμα.
  // ─────────────────────────────────────────────────────────────
  static double resolveWidth(BuildContext context, BoxConstraints? constraints) {
    if (constraints != null && constraints.maxWidth.isFinite) {
      return constraints.maxWidth;
    }
    return MediaQuery.of(context).size.width;
  }

  // ─────────────────────────────────────────────────────────────
  // PURE WIDTH-BASED (no MediaQuery dependency)
  // ─────────────────────────────────────────────────────────────
  static ScreenBreakpoint breakpointFromWidth(double w) {
    final bp = w < 600
        ? ScreenBreakpoint.mobile
        : w < 900
            ? ScreenBreakpoint.tablet
            : ScreenBreakpoint.desktop;
    DebugConfig.log(DebugConfig.uiRebuild, 'breakpointFromWidth: ${w.toStringAsFixed(0)}px → $bp');
    return bp;
  }

  static bool isMobileFromWidth(double w) => breakpointFromWidth(w) == ScreenBreakpoint.mobile;
  static bool isTabletFromWidth(double w) => breakpointFromWidth(w) == ScreenBreakpoint.tablet;
  static bool isDesktopFromWidth(double w) => breakpointFromWidth(w) == ScreenBreakpoint.desktop;

  static double paddingValueFromWidth(double w) {
    switch (breakpointFromWidth(w)) {
      case ScreenBreakpoint.mobile:
        return 16;
      case ScreenBreakpoint.tablet:
        return 24;
      case ScreenBreakpoint.desktop:
        return 32;
    }
  }

  static EdgeInsets paddingFromWidth(double w) {
    final v = paddingValueFromWidth(w);
    return EdgeInsets.symmetric(horizontal: v, vertical: v * 0.5);
  }

  static EdgeInsets horizontalPaddingFromWidth(double w) {
    return EdgeInsets.symmetric(horizontal: paddingValueFromWidth(w));
  }

  static double maxContentWidthFromWidth(double w) {
    switch (breakpointFromWidth(w)) {
      case ScreenBreakpoint.mobile:
        return double.infinity;
      case ScreenBreakpoint.tablet:
        return 600;
      case ScreenBreakpoint.desktop:
        return 900;
    }
  }

  static double gridColumnsFromWidth(double w) {
    switch (breakpointFromWidth(w)) {
      case ScreenBreakpoint.mobile:
        return 1;
      case ScreenBreakpoint.tablet:
        return 2;
      case ScreenBreakpoint.desktop:
        return 3;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CONTEXT-BASED (delegate through resolveWidth — backward compat)
  // ─────────────────────────────────────────────────────────────
  static ScreenBreakpoint breakpoint(BuildContext context) => breakpointFromWidth(resolveWidth(context, null));
  static bool isMobile(BuildContext context) => isMobileFromWidth(resolveWidth(context, null));
  static bool isTablet(BuildContext context) => isTabletFromWidth(resolveWidth(context, null));
  static bool isDesktop(BuildContext context) => isDesktopFromWidth(resolveWidth(context, null));
  static double paddingValue(BuildContext context) => paddingValueFromWidth(resolveWidth(context, null));
  static EdgeInsets padding(BuildContext context) => paddingFromWidth(resolveWidth(context, null));
  static EdgeInsets horizontalPadding(BuildContext context) => horizontalPaddingFromWidth(resolveWidth(context, null));
  static double maxContentWidth(BuildContext context) => maxContentWidthFromWidth(resolveWidth(context, null));
  static double gridColumns(BuildContext context) => gridColumnsFromWidth(resolveWidth(context, null));

  // ─────────────────────────────────────────────────────────────
  // GENUINELY NEED CONTEXT (viewInsets, safeArea — NOT size)
  // ─────────────────────────────────────────────────────────────
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
}

/// Wraps child in a [LayoutBuilder] and passes [ScreenBreakpoint] derived
/// from constraints (no MediaQuery rebuild cascade).
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenBreakpoint breakpoint) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return builder(context, ResponsiveUtils.breakpointFromWidth(w));
        },
      );
}

/// Applies responsive horizontal padding derived from LayoutBuilder
/// constraints (no MediaQuery rebuild cascade).
class ResponsivePadding extends StatelessWidget {
  final Widget child;

  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return Padding(
            padding: ResponsiveUtils.paddingFromWidth(w),
            child: child,
          );
        },
      );
}
