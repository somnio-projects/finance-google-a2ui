import 'package:finance_app/charts/waterfall_overlay.dart';
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

void main() {
  final layout = WaterfallLayout.of(
    steps: harnessSteps,
    width: 700,
    height: 200,
  );

  WaterfallOverlay overlay(double width) =>
      WaterfallOverlay(width: width, builder: (context, dx) => Text('$dx'));

  Positioned positioned({
    WaterfallSelection? selection,
    WaterfallOverlay? subject,
  }) =>
      waterfallOverlayChildren(
            _NullContext(),
            layout: layout,
            selection: selection,
            overlay: subject,
            plotHeight: 200,
          ).single
          as Positioned;

  group('waterfallOverlayChildren', () {
    test('places the overlay centred on its bar, above it', () {
      final child = positioned(selection: _first, subject: overlay(232));
      final bar = layout.bars[1];
      expect(child.left! + 232 / 2, closeTo(bar.rect.topCenter.x, 0.01));
      expect(child.width, 232);
      expect(
        child.bottom,
        closeTo(200 - bar.rect.top + WaterfallOverlay.gap, 0.01),
      );
    });

    test('clamps an overlay that would leave the plot, and still aims it', () {
      // The last bar's centre is 50 px from the right edge, so a 232-wide
      // callout has to move left — and the pointer has to follow it, or the
      // callout stops being an annotation of that bar (AC-3).
      final child = positioned(
        selection: const WaterfallSelection(
          index: 6,
          barFill: Color(0xFF0C6349),
          column: Color(0xFFE8FEF3),
        ),
        subject: overlay(232),
      );
      expect(child.left! + 232, lessThanOrEqualTo(700.01));
      // The builder is handed the pointer offset; it prints it, so the
      // assertion reads what the callout would actually have drawn with.
      expect(
        (child.child as Text).data,
        '${layout.bars[6].rect.topCenter.x - child.left!}',
      );
    });

    test('draws nothing without a selection, an overlay, or a real bar', () {
      List<Widget> children({
        WaterfallSelection? selection,
        WaterfallOverlay? subject,
      }) => waterfallOverlayChildren(
        _NullContext(),
        layout: layout,
        selection: selection,
        overlay: subject,
        plotHeight: 200,
      );
      expect(children(subject: overlay(232)), isEmpty);
      expect(children(selection: _first), isEmpty);
      expect(
        children(
          selection: const WaterfallSelection(
            index: 99,
            barFill: Color(0xFF0C6349),
            column: Color(0xFFE8FEF3),
          ),
          subject: overlay(232),
        ),
        isEmpty,
      );
    });
  });

  group('waterfallColumnChildren', () {
    test('spans the selected band and stretches to the stack', () {
      final child =
          waterfallColumnChildren(
                bandScale: layout.bandScale,
                selection: _first,
                radius: 6,
              ).single
              as Positioned;
      expect(child.left, closeTo(100, 0.01));
      expect(child.width, closeTo(100, 0.01));
      expect(child.top, 0);
      expect(child.bottom, 0);
    });

    test('draws nothing when nothing is selected', () {
      expect(
        waterfallColumnChildren(
          bandScale: layout.bandScale,
          selection: null,
          radius: 6,
        ),
        isEmpty,
      );
    });
  });
}

/// The overlay builder never touches its context, so a stub is honest here
/// and keeps the suite a plain `test` rather than a pumped widget.
class _NullContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
