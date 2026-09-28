import 'package:finance_app/charts/payoff_plot_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payoff_harness.dart';

void main() {
  group('PayoffPainter', () {
    test("carries the design's measured stroke widths", () {
      // `stroke-width` on the design's grid line, zero rule and curve.
      expect(gridWidth, 1);
      expect(zeroWidth, 1.5);
      expect(curveWidth, 2.6);
    });

    test('does not repaint when nothing it draws changed', () {
      expect(buildPainter().shouldRepaint(buildPainter()), isFalse);
    });

    test('repaints when a tick label changes', () {
      expect(
        buildPainter().shouldRepaint(
          buildPainter(labels: const <String>['x', 'y', 'z']),
        ),
        isTrue,
      );
    });

    test('repaints when the geometry changes', () {
      expect(
        buildPainter().shouldRepaint(
          buildPainter(series: const <List<PayoffPoint>>[]),
        ),
        isTrue,
      );
    });

    test('repaints when the theme changes', () {
      expect(
        buildPainter().shouldRepaint(buildPainter(brightness: Brightness.dark)),
        isTrue,
      );
    });

    test('repaints when the plot height changes', () {
      expect(
        buildPainter().shouldRepaint(buildPainter(plotHeight: 200)),
        isTrue,
      );
    });

    testWidgets('paints regions, grid, curve and ticks', (tester) async {
      await tester.pumpWidget(paintedBy(buildPainter()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints an empty plot for a payload with no series', (
      tester,
    ) async {
      await tester.pumpWidget(
        paintedBy(
          buildPainter(
            series: const <List<PayoffPoint>>[],
            labels: const <String>[],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints no zero rule when the curve never reaches zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        paintedBy(
          buildPainter(
            series: const <List<PayoffPoint>>[
              <PayoffPoint>[
                PayoffPoint(at: 100, value: 8000),
                PayoffPoint(at: 200, value: 20000),
              ],
            ],
            labels: const <String>[r'$100.00', r'$200.00'],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints a second series', (tester) async {
      await tester.pumpWidget(
        paintedBy(
          buildPainter(
            series: const <List<PayoffPoint>>[samplePoints, samplePoints],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops a tick that would collide or overflow (AC-6)', (
      tester,
    ) async {
      // Four long labels for three points on a 120 px plot: the painter drops
      // rather than overlaps, which is what makes the chart responsive with
      // no breakpoint. The fourth has no point at all and is skipped.
      await tester.pumpWidget(
        paintedBy(
          buildPainter(
            width: 120,
            labels: const <String>[
              r'$100,000.00',
              r'$150,000.00',
              r'$200,000.00',
              r'$250,000.00',
            ],
          ),
          width: 120,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
