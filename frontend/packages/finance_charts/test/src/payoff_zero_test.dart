import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../payoff_reference.dart';

/// Where the zero rule sits — the one piece of this layout that is a *claim*
/// rather than a placement, so it is asserted apart from the rest.
void main() {
  PayoffLayout over(List<PayoffPoint> points) => PayoffLayout.of(
    series: <List<PayoffPoint>>[points],
    width: designPlotWidth,
    height: designPlotHeight,
  );

  group('payoffZero', () {
    const scale = LinearScale(
      domainMin: -5000,
      domainMax: 20000,
      rangeMin: 226,
      rangeMax: 0,
    );

    test('places zero inside the plot when the domain straddles it', () {
      final zero = payoffZero(
        (min: -5000.0, max: 20000.0, step: 5000.0),
        scale,
        226,
      );
      expect(zero.inDomain, isTrue);
      expect(zero.y, closeTo(scale(0), 1e-12));
    });

    test('clamps to the floor when the domain is entirely above zero', () {
      const positive = LinearScale(
        domainMin: 5000,
        domainMax: 20000,
        rangeMin: 226,
        rangeMax: 0,
      );
      final zero = payoffZero(
        (min: 5000.0, max: 20000.0, step: 5000.0),
        positive,
        226,
      );
      expect(zero.inDomain, isFalse);
      // Unclamped this would be 301.3 — below the canvas, and it would invert
      // the loss rect the layout builds from it.
      expect(zero.y, 226);
    });

    test('clamps to the ceiling when the domain is entirely below zero', () {
      const negative = LinearScale(
        domainMin: -20000,
        domainMax: -5000,
        rangeMin: 226,
        rangeMax: 0,
      );
      final zero = payoffZero(
        (min: -20000.0, max: -5000.0, step: 5000.0),
        negative,
        226,
      );
      expect(zero.inDomain, isFalse);
      expect(zero.y, 0);
    });
  });

  group('PayoffLayout zero rule', () {
    test('is present and on the plot when the curve straddles zero', () {
      final layout = over(designCurve);
      expect(layout.zeroInDomain, isTrue);
      expect(layout.zeroY, closeTo(layout.valueScale(0), 1e-12));
    });

    test('is absent, and the regions stay well formed, when it is not', () {
      final layout = over(const <PayoffPoint>[
        PayoffPoint(at: 100, value: 8000),
        PayoffPoint(at: 200, value: 20000),
      ]);
      expect(layout.zeroInDomain, isFalse);
      expect(layout.zeroY, inInclusiveRange(0, designPlotHeight));
      expect(
        layout.lossRegion.top,
        lessThanOrEqualTo(layout.lossRegion.bottom),
      );
      expect(
        layout.gainRegion.top,
        lessThanOrEqualTo(layout.gainRegion.bottom),
      );
    });

    test('is absent for a plot with nothing on it', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      expect(layout.zeroInDomain, isFalse);
    });
  });
}
