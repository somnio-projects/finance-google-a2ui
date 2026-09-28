import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

/// GGU-146 — placing the two markers, and splitting the plot between them.
void main() {
  const points = <PayoffPoint>[
    PayoffPoint(at: 100, value: -200),
    PayoffPoint(at: 150, value: 0),
    PayoffPoint(at: 200, value: 200),
  ];
  const priceScale = LinearScale(
    domainMin: 100,
    domainMax: 200,
    rangeMin: 0,
    rangeMax: 400,
  );
  const valueScale = LinearScale(
    domainMin: -200,
    domainMax: 200,
    rangeMin: 200,
    rangeMax: 0,
  );

  PayoffMark? mark(double at) => payoffMark(
    points: points,
    at: at,
    priceScale: priceScale,
    valueScale: valueScale,
  );

  group('payoffMark', () {
    test('lands on a sample exactly', () {
      expect(mark(150), (x: 200.0, y: 100.0));
    });

    test('interpolates between two samples rather than snapping to one', () {
      // 175 is halfway from 150 to 200, so the value is halfway from 0 to
      // 200. Snapping to the nearer sample would put the dot 50 px off the
      // line it is supposed to sit on, which is the whole reason this
      // function exists rather than an index lookup.
      expect(mark(175), (x: 300.0, y: 50.0));
    });

    test('answers nothing for a price the curve was never sampled at', () {
      expect(mark(99), isNull);
      expect(mark(201), isNull);
    });

    test('answers nothing when there is no curve', () {
      expect(
        payoffMark(
          points: const <PayoffPoint>[],
          at: 150,
          priceScale: priceScale,
          valueScale: valueScale,
        ),
        isNull,
      );
    });

    test('places a marker on a curve sampled once, at that one price', () {
      // `points.first`/`points.last` are the same sample, so the loop never
      // runs and the fallthrough is the answer.
      expect(
        payoffMark(
          points: const <PayoffPoint>[PayoffPoint(at: 150, value: 0)],
          at: 150,
          priceScale: priceScale,
          valueScale: valueScale,
        ),
        (x: 200.0, y: 100.0),
      );
    });
  });
}
