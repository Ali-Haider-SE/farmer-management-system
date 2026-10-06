import 'package:flutter/material.dart';

/// Central place for every screen-size decision in the app.
///
/// Breakpoints are chosen to comfortably cover the sizes the app is
/// tested against: 390 / 430 (phones), 768 (small tablet / split view),
/// 1024 (tablet landscape / small laptop), 1366 (laptop) and 1920
/// (desktop monitor).
class Responsive {
  Responsive._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  /// True once the screen is wide enough to show a permanent sidebar
  /// instead of a Drawer (matches the 768px tablet breakpoint so the
  /// nav collapses on phones AND small/split-view tablets).
  static bool showPermanentSidebar(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  /// Picks a value based on the current width. Falls back from the
  /// closest larger breakpoint down to [mobileValue] if a size isn't
  /// provided, so callers only need to override what actually changes.
  static T value<T>(
    BuildContext context, {
    required T mobileValue,
    T? tabletValue,
    T? desktopValue,
  }) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= tablet && desktopValue != null) return desktopValue;
    if (width >= mobile && tabletValue != null) return tabletValue;

    return mobileValue;
  }

  /// Column count for card/stat grids, based on the width that's
  /// actually available to the grid (pass `constraints.maxWidth` from
  /// a LayoutBuilder, not the full screen width, since a sidebar or
  /// padding may already have eaten into it).
  static int gridColumns(double availableWidth, {double minItemWidth = 220}) {
    final columns = (availableWidth / minItemWidth).floor();
    return columns < 1 ? 1 : columns;
  }
}
