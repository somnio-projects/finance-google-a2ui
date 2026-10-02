import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_app/charts/waterfall_overlay_layout.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'waterfall_harness.dart';

const WaterfallSelection _first = WaterfallSelection(
  index: 1,
  barFill: Color(0xFF0C6349),
  column: Color(0xFFE8FEF3),
);

/// The delegate that places the callout once its measured height is known
/// (spec frontend/0028 OD-4). The arithmetic it leans on is proved on its own
/// in `finance_charts`; these assert that the delegate uses it, and that the
/// vertical clamp — the one the first build had no lower bound for — holds.
void main() {
  final layout = WaterfallLayout.of(
    steps: harnessSteps,
    width: 700,
    height: 200,
  );

  WaterfallOverlay overlay(double width) =>
      WaterfallOverlay(width: width, builder: (context, dx) => Text('$dx'));

  WaterfallOverlayLayout delegateOf({
    WaterfallSelection? selection,
    WaterfallOverlay? subject,
  }) {
    final placed =
        waterfallOverlayChildren(
              _NullContext(),
              layout: layout,
              selection: selection,
              overlay: subject,
              plotHeight: 200,
            ).single
            as Positioned;
    final laidOut = placed.child as CustomSingleChildLayout;
    return laidOut.delegate as WaterfallOverlayLayout;
  }

  group(WaterfallOverlayLayout, () {
    test('clamps a callout that has no room above its bar', () {
      // AC-7: the tallest bar in a walk leaves the least headroom, and the
      // card clips. Asserted through the delegate because the height is what
      // decides it, and only the delegate ever sees a measured height.
      final peak = layout.bars.reduce(
        (a, b) => a.rect.top < b.rect.top ? a : b,
      );
      final delegate = delegateOf(
        selection: WaterfallSelection(
          index: peak.index,
          barFill: const Color(0xFF0C6349),
          column: const Color(0xFFE8FEF3),
        ),
        subject: overlay(232),
      );
      final at = delegate.getPositionForChild(
        const Size(700, 200),
        const Size(232, 140),
      );
      expect(at.dy, greaterThanOrEqualTo(0));
      expect(at.dy + 140, lessThanOrEqualTo(200.01));
    });

    test('relayouts when the bar it is anchored on moves', () {
      final delegate = delegateOf(selection: _first, subject: overlay(232));
      expect(delegate.shouldRelayout(delegate), isFalse);
      expect(
        delegate.shouldRelayout(
          const WaterfallOverlayLayout(
            left: 0,
            width: 232,
            barTop: 10,
            plotHeight: 200,
          ),
        ),
        isTrue,
      );
    });

    test('gives the child the overlay width it declared', () {
      final delegate = delegateOf(selection: _first, subject: overlay(232));
      final constraints = delegate.getConstraintsForChild(
        const BoxConstraints(maxWidth: 700, maxHeight: 200),
      );
      expect(constraints.minWidth, 232);
      expect(constraints.maxWidth, 232);
      expect(constraints.maxHeight, 200);
    });
  });
}

/// The overlay builder never touches its context, so a stub is honest here
/// and keeps the suite a plain `test` rather than a pumped widget.
class _NullContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
