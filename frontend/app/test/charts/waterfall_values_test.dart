import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const WaterfallSelection _first = WaterfallSelection(
  index: 1,
  barFill: Color(0xFF0C6349),
  column: Color(0xFFE8FEF3),
);

/// Equality on the two values a chart is handed, which is what decides
/// whether the plot repaints (spec frontend/0028).
void main() {
  WaterfallOverlay overlay(double width) =>
      WaterfallOverlay(width: width, builder: (context, dx) => Text('$dx'));

  group('the values a chart is handed', () {
    test('two selections of the same step in the same colours are equal', () {
      // Equality is what `shouldRepaint` reads, so a selection that compared
      // by identity would repaint the plot on every rebuild.
      expect(
        _first,
        const WaterfallSelection(
          index: 1,
          barFill: Color(0xFF0C6349),
          column: Color(0xFFE8FEF3),
        ),
      );
      expect(
        _first,
        isNot(
          const WaterfallSelection(
            index: 2,
            barFill: Color(0xFF0C6349),
            column: Color(0xFFE8FEF3),
          ),
        ),
      );
    });

    test('two overlays of the same width are equal', () {
      // The builder is deliberately outside `props`: one closure is never
      // equal to another, so comparing it would make every overlay unequal
      // to itself and defeat the point.
      expect(overlay(232), overlay(232));
      expect(overlay(232), isNot(overlay(200)));
    });
  });
}
