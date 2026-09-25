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

void main() {
  final layout = WaterfallLayout.of(
    steps: harnessSteps,
    width: 700,
    height: 200,
  );

  WaterfallOverlay overlay(double width) =>
      WaterfallOverlay(width: width, builder: (context, dx) => Text('$dx'));

  CustomSingleChildLayout laidOut({
    WaterfallSelection? selection,
    WaterfallOverlay? subject,
  }) =>
      (waterfallOverlayChildren(
                    _NullContext(),
                    layout: layout,
                    selection: selection,
                    overlay: subject,
                    plotHeight: 200,
                  ).single
                  as Positioned)
              .child
          as CustomSingleChildLayout;

  WaterfallOverlayLayout delegateOf({
    WaterfallSelection? selection,
    WaterfallOverlay? subject,
  }) =>
      laidOut(selection: selection, subject: subject).delegate
          as WaterfallOverlayLayout;

  group('waterfallOverlayChildren', () {
    test('places the overlay centred on its bar, a gap above it', () {
      // Band 3, and a short overlay, because this is the unclamped case and
      // most bands of this walk are not it: the plot is 700 px over seven
      // bands, so a 232-wide callout only fits centred over a middle band,
      // and `BTC` is the walk's high-water mark with no room above it at all.
      // The preconditions are asserted rather than assumed — a test of the
      // *unclamped* placement that silently ran a clamped one would pass for
      // the wrong reason.
      const height = 12.0;
      final bar = layout.bars[3];
      expect(bar.rect.top, greaterThan(height + WaterfallOverlay.gap));
      expect(bar.rect.topCenter.x - 232 / 2, greaterThan(0));
      expect(bar.rect.topCenter.x + 232 / 2, lessThan(700));

      final delegate = delegateOf(
        selection: const WaterfallSelection(
          index: 3,
          barFill: Color(0xFF0C6349),
          column: Color(0xFFE8FEF3),
        ),
        subject: overlay(232),
      );
      final at = delegate.getPositionForChild(
        const Size(700, 200),
        const Size(232, height),
      );
      expect(at.dx + 232 / 2, closeTo(bar.rect.topCenter.x, 0.01));
      expect(
        at.dy,
        closeTo(bar.rect.top - WaterfallOverlay.gap - height, 0.01),
      );
      expect(delegate.width, 232);
    });

    test('clamps an overlay that would leave the plot, and still aims it', () {
      // The last bar's centre is 50 px from the right edge, so a 232-wide
      // callout has to move left — and the pointer has to follow it, or the
      // callout stops being an annotation of that bar (AC-3).
      final subject = laidOut(
        selection: const WaterfallSelection(
          index: 6,
          barFill: Color(0xFF0C6349),
          column: Color(0xFFE8FEF3),
        ),
        subject: overlay(232),
      );
      final delegate = subject.delegate as WaterfallOverlayLayout;
      expect(delegate.left + 232, lessThanOrEqualTo(700.01));
      // The builder is handed the pointer offset; it prints it, so the
      // assertion reads what the callout would actually have drawn with.
      expect(
        (subject.child! as Text).data,
        '${layout.bars[6].rect.topCenter.x - delegate.left}',
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
}

/// The overlay builder never touches its context, so a stub is honest here
/// and keeps the suite a plain `test` rather than a pumped widget.
class _NullContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
