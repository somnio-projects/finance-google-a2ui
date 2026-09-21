import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_border.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ScenarioComparisonLayout, () {
    test('narrows the metric track as scenarios are added', () {
      // Both measured: `1.35fr` on the two-scenario artboard, `1.2fr` on the
      // three. Expressed against a 100-unit scenario track.
      expect(ScenarioComparisonLayout.metricFlex(2), 135);
      expect(ScenarioComparisonLayout.metricFlex(3), 120);
      expect(ScenarioComparisonLayout.scenarioFlex, 100);
    });

    test('falls back to the tightest ratio the designer has drawn', () {
      // Unreachable through the contract — the options model requires two
      // methods and caps at three — so this is a defined answer rather than
      // a line fitted through two points.
      expect(ScenarioComparisonLayout.metricFlex(4), 120);
      expect(ScenarioComparisonLayout.metricFlex(0), 120);
    });

    test('carries the measured cell paddings and radii', () {
      expect(ScenarioComparisonLayout.columnGap, 8);
      expect(ScenarioComparisonLayout.hairline, 1);
      expect(ScenarioComparisonLayout.cardRadius, 16);
      expect(ScenarioComparisonLayout.headerCellRadius, 10);
      expect(ScenarioComparisonLayout.valueCellRadius, 8);
      expect(
        ScenarioComparisonLayout.cardPadding,
        const EdgeInsets.fromLTRB(18, 16, 18, 15),
      );
      expect(
        ScenarioComparisonLayout.headerCellPadding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );
      expect(
        ScenarioComparisonLayout.valueCellPadding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      );
      expect(
        ScenarioComparisonLayout.metricCellPadding,
        const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
      );
      expect(
        ScenarioComparisonLayout.metricHeaderPadding,
        const EdgeInsets.fromLTRB(2, 0, 2, 4),
      );
      expect(
        ScenarioComparisonLayout.rowPadding,
        const EdgeInsets.symmetric(vertical: 2),
      );
    });
  });

  group(ScenarioComparisonText, () {
    const black = Color(0xFF000000);

    test('sets each type slot to its measured size and weight', () {
      expect(ScenarioComparisonText.caption(black).fontSize, 10);
      expect(ScenarioComparisonText.caption(black).fontWeight, FontWeight.w600);
      expect(ScenarioComparisonText.caption(black).letterSpacing, 0.8);
      expect(ScenarioComparisonText.columnTitle(black).fontSize, 12.5);
      expect(
        ScenarioComparisonText.columnTitle(black).fontWeight,
        FontWeight.w500,
      );
      expect(ScenarioComparisonText.columnLabel(black).fontSize, 10);
      expect(ScenarioComparisonText.metricLabel(black).fontSize, 12);
      expect(ScenarioComparisonText.value(black).fontSize, 13.5);
    });

    test('draws the Metric caption at 500, not as an eyebrow', () {
      // Both artboards of both design exports: weight 500, normal tracking.
      // Reusing `caption` (600 at 0.08em) here was a real fidelity miss.
      final heading = ScenarioComparisonText.metricHeading(black);
      expect(heading.fontSize, 10);
      expect(heading.fontWeight, FontWeight.w500);
      expect(heading.letterSpacing, isNull);
      expect(
        heading.fontWeight,
        isNot(ScenarioComparisonText.caption(black).fontWeight),
      );
    });

    test('lines the digits up without bundling a mono face', () {
      // The design sets these in Roboto Mono; the reason is column
      // alignment, and `tabularFigures` buys that from the bundled font.
      // Recorded as an open decision with design (`specs/frontend/0004`
      // OD-5), the same way `ChartText` records it.
      expect(
        ScenarioComparisonText.value(black).fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group(ScenarioHeaderBorderPainter, () {
    test('repaints only when its colour or radius changes', () {
      const painter = ScenarioHeaderBorderPainter(
        color: Color(0xFFEAE7F0),
        radius: 10,
      );
      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          const ScenarioHeaderBorderPainter(
            color: Color(0xFF2A2B33),
            radius: 10,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ScenarioHeaderBorderPainter(
            color: Color(0xFFEAE7F0),
            radius: 9,
          ),
        ),
        isTrue,
      );
    });

    test('draws a hairline the width the design measures', () {
      expect(ScenarioHeaderBorderPainter.strokeWidth, 1);
    });
  });
}
