import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';

/// Lays out a set of equal-sized cards (stat/summary cards, quick
/// actions, etc.) that sit in one row on wide screens but drop down to
/// fewer columns automatically as the available width shrinks — so
/// they never get squeezed thin enough to overflow on a phone.
///
/// This replaces the old pattern of `GridView.count(crossAxisCount: 4)`
/// which stayed at a fixed column count on every screen size.
class ResponsiveCardRow extends StatelessWidget {
  const ResponsiveCardRow({
    super.key,
    required this.children,
    this.spacing = 15,
    this.runSpacing = 15,
    this.minCardWidth = 220,
    this.aspectRatio = 2.6,
    this.maxColumns,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  /// Below this width a card drops to the next row instead of shrinking.
  final double minCardWidth;
  final double aspectRatio;

  /// Optional cap so a row of e.g. 2 cards doesn't stretch across a
  /// 1920px screen looking for extra columns that don't exist.
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = Responsive.gridColumns(
          constraints.maxWidth,
          minItemWidth: minCardWidth,
        );

        if (columns > children.length) columns = children.length;
        if (maxColumns != null && columns > maxColumns!) columns = maxColumns!;

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          shrinkWrap: true,
          childAspectRatio: aspectRatio,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}
