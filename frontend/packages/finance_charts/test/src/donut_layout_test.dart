import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../donut_design_reference.dart';

/// Where [arc] ends, in CSS degrees clockwise from twelve o'clock.
///
/// The design expresses the ring as a `conic-gradient(from 0deg, …)`; this
/// puts a [DonutArc] in the same units so the two can be compared directly
/// rather than by eye.
double endDegrees(DonutArc arc) =>
    (arc.startAngle + arc.sweepAngle - twelveOClock) / tau * 360;

void main() {
  group(DonutLayout, () {
    test("starts the first slice at twelve o'clock", () {
      final layout = DonutLayout.of(
        weights: designClassWeights,
        width: 100,
        height: 100,
      );
      expect(layout.arcs.first.startAngle, equals(twelveOClock));
    });

    test('sweeps a full turn in total, however the weights are scaled', () {
      // The contract says the weights sum to one; normalising by their sum is
      // what closes the ring when the backend's rounding lands at 0.9999.
      for (final weights in <List<double>>[
        const <double>[0.5927, 0.2445, 0.0937, 0.0455, 0.0235],
        const <double>[62, 18, 8, 12],
        const <double>[1, 1, 1],
      ]) {
        final layout = DonutLayout.of(weights: weights, width: 80, height: 80);
        var total = 0.0;
        for (final arc in layout.arcs) {
          total += arc.sweepAngle;
        }
        expect(total, closeTo(tau, 1e-12));
      }
    });

    test('gives a single holding the whole ring', () {
      final layout = DonutLayout.of(
        weights: const <double>[1],
        width: 80,
        height: 80,
      );
      expect(layout.arcs, hasLength(1));
      expect(layout.arcs.single.sweepAngle, closeTo(tau, 1e-12));
      expect(layout.isEmpty, isFalse);
    });

    test('keeps a zero weight as a zero-sweep arc at its own index', () {
      // Arc *i* is category *i*, so the legend's colour and the ring's
      // colour cannot drift apart when the backend sends an empty bucket.
      final layout = DonutLayout.of(
        weights: const <double>[1, 0, 1],
        width: 80,
        height: 80,
      );
      expect(layout.arcs.map((a) => a.index), equals(<int>[0, 1, 2]));
      expect(layout.arcs[1].sweepAngle, isZero);
      expect(layout.arcs[1].startAngle, equals(layout.arcs[2].startAngle));
    });

    test('draws nothing for an empty portfolio', () {
      final layout = DonutLayout.of(
        weights: const <double>[],
        width: 80,
        height: 80,
      );
      expect(layout.isEmpty, isTrue);
      expect(layout.arcs, isEmpty);
    });

    test('draws nothing when every weight is non-positive', () {
      final layout = DonutLayout.of(
        weights: const <double>[0, 0],
        width: 80,
        height: 80,
      );
      expect(layout.isEmpty, isTrue);
    });

    test("sizes the ring to the shorter side and the design's hole", () {
      final layout = DonutLayout.of(
        weights: const <double>[1],
        width: designOuterDiameter,
        height: designOuterDiameter,
      );
      expect(layout.outerRadius, equals(designOuterDiameter / 2));
      expect(layout.innerRadius, closeTo(designHoleDiameter / 2, 0.001));
      expect(layout.thickness, closeTo((150 - 92) / 2, 0.001));
      expect(layout.strokeRadius, closeTo((75 + 46) / 2, 0.001));
      expect(layout.center, equals(const ChartPoint(75, 75)));
    });

    test('fits a ring into a non-square plot, and collapses a flat one', () {
      final wide = DonutLayout.of(
        weights: const <double>[1],
        width: 200,
        height: 60,
      );
      expect(wide.outerRadius, equals(30));
      final flat = DonutLayout.of(
        weights: const <double>[1],
        width: 0,
        height: 0,
      );
      expect(flat.outerRadius, isZero);
      expect(flat.innerRadius, isZero);
    });

    test('is a value, and says what it holds', () {
      final a = DonutLayout.of(
        weights: const <double>[1, 1],
        width: 80,
        height: 80,
      );
      final b = DonutLayout.of(
        weights: const <double>[1, 1],
        width: 80,
        height: 80,
      );
      expect(a, equals(b));
      expect(a.arcs.first, equals(b.arcs.first));
      expect(a.arcs.first.toString(), contains('DonutArc(0'));
      expect(a.arcs.first.props, isNotEmpty);
    });
  });
}
