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

/// The tint behind a selected band (spec frontend/0028 OD-3, AC-2).
void main() {
  final layout = WaterfallLayout.of(
    steps: harnessSteps,
    width: 700,
    height: 200,
  );

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
