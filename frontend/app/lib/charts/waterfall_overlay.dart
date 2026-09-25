import 'package:equatable/equatable.dart';
import 'package:finance_app/charts/waterfall_overlay_layout.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Something floated above the selected bar, of a width it declares up front.
///
/// The width is **given**, not measured, and that is the whole reason this
/// shape exists: the callout carries a pointer that has to land on the bar's
/// centre, so its horizontal position and the pointer's offset inside it have
/// to be computed together, in one pass. A widget that sized itself would
/// know its own width one layout too late.
class WaterfallOverlay extends Equatable {
  /// Creates an overlay [width] pixels wide.
  const WaterfallOverlay({required this.width, required this.builder});

  /// The gap between the bar's top edge and the overlay's lower edge.
  static const double gap = 6;

  /// The overlay's fixed width.
  final double width;

  /// Builds the overlay, told where the bar's centre falls inside it.
  ///
  /// `pointerDx` is measured from the overlay's own left edge, so a callout
  /// clamped against the plot's edge still points at its bar.
  final Widget Function(BuildContext context, double pointerDx) builder;

  @override
  List<Object?> get props => <Object?>[width];
}

/// The tinted band behind the selected step, or nothing when none is.
///
/// A list for the same reason [waterfallOverlayChildren] returns one: the
/// caller spreads it into a `Stack` and never branches. The column stretches
/// to the stack's full height, which in the chart is the plot *and* the axis
/// row — the UI Kit carries the tint under the bold category name.
List<Widget> waterfallColumnChildren({
  required BandScale bandScale,
  required WaterfallSelection? selection,
  required double radius,
}) {
  if (selection == null) return const <Widget>[];
  final column = waterfallColumn(bandScale, selection.index, height: 0);
  return <Widget>[
    Positioned(
      left: column.left,
      width: column.width,
      top: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selection.column,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
  ];
}

/// The overlay's positioned child, or nothing when there is none to draw.
///
/// Returns a list so a `Stack` can spread it: a selected bar with no overlay,
/// an overlay with no selection and an index past the end of the walk all
/// produce the same empty result rather than three branches at the call site.
List<Widget> waterfallOverlayChildren(
  BuildContext context, {
  required WaterfallLayout layout,
  required WaterfallSelection? selection,
  required WaterfallOverlay? overlay,
  required double plotHeight,
}) {
  final index = selection?.index;
  if (overlay == null || index == null || index >= layout.bars.length) {
    return const <Widget>[];
  }
  final bar = layout.bars[index];
  final left = clampedLabelLeft(
    center: bar.rect.topCenter.x,
    width: overlay.width,
    plotWidth: layout.bandScale.width,
  );
  return <Widget>[
    Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: WaterfallOverlayLayout(
          left: left,
          width: overlay.width,
          barTop: bar.rect.top,
          plotHeight: plotHeight,
        ),
        child: overlay.builder(context, bar.rect.topCenter.x - left),
      ),
    ),
  ];
}
