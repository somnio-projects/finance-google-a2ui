import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Places the overlay, once its own height is known.
///
/// A `Positioned` cannot do this: the vertical clamp needs the callout's
/// **measured** height, and a callout's height depends on how far its
/// identity line wraps. A layout delegate is handed that height and still
/// answers in one pass, which is the same reason [WaterfallOverlay.width] is
/// given rather than measured — the horizontal position and the pointer's
/// offset inside the callout are decided before the child is built.
@visibleForTesting
class WaterfallOverlayLayout extends SingleChildLayoutDelegate {
  /// Creates a delegate for one selected bar.
  const WaterfallOverlayLayout({
    required this.left,
    required this.width,
    required this.barTop,
    required this.plotHeight,
  });

  /// The already-clamped left edge, which the pointer's offset was measured
  /// against.
  final double left;

  /// The overlay's given width.
  final double width;

  /// The selected bar's top edge, in the plot's coordinates.
  final double barTop;

  /// The plot's height, which is what the callout is clamped inside.
  final double plotHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    left,
    clampedOverlayTop(
      barTop: barTop,
      height: childSize.height,
      gap: WaterfallOverlay.gap,
      plotHeight: plotHeight,
    ),
  );

  @override
  bool shouldRelayout(WaterfallOverlayLayout oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.width != width ||
      oldDelegate.barTop != barTop ||
      oldDelegate.plotHeight != plotHeight;
}
