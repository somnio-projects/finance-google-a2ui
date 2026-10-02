import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

/// GGU-146 — the value axis draws the ladder the backend chose.
void main() {
  _rungs();
}

/// The value axis's rungs come from the backend when it sends them.
void _rungs() {
  const scale = LinearScale(
    domainMin: -200,
    domainMax: 200,
    rangeMin: 200,
    rangeMax: 0,
  );
  const bounds = (min: -200.0, max: 200.0, step: 200.0);

  group('payoffRungs', () {
    test("maps the backend's own ladder, in the order it arrived", () {
      // The reason the field exists: a client choosing its own rungs would
      // be computing a figure it then has to label (N-2).
      expect(
        payoffRungs(
          valueTicks: const <double>[-200, 0, 200],
          bounds: bounds,
          valueScale: scale,
          empty: false,
        ),
        <double>[200, 100, 0],
      );
    });

    test('falls back to the rounded axis when the payload sent none', () {
      expect(
        payoffRungs(
          valueTicks: const <double>[],
          bounds: bounds,
          valueScale: scale,
          empty: false,
        ),
        payoffGridLines(bounds, scale),
      );
    });

    test('draws no rule at all over a plot with no curve', () {
      expect(
        payoffRungs(
          valueTicks: const <double>[0],
          bounds: bounds,
          valueScale: scale,
          empty: true,
        ),
        isEmpty,
      );
    });
  });
}
