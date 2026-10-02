import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

/// GGU-146 — splitting a plot between the two sides of a break-even.
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

  group('payoffZones', () {
    test('splits vertically, losing on the side the curve loses on', () {
      final zones = payoffZones(
        x: 200,
        width: 400,
        height: 200,
        leftIsLoss: true,
      );

      expect(
        zones.loss,
        const ChartRect(left: 0, top: 0, right: 200, bottom: 200),
      );
      expect(
        zones.gain,
        const ChartRect(left: 200, top: 0, right: 400, bottom: 200),
      );
    });

    test('mirrors for a sale, which loses as the price rises', () {
      final zones = payoffZones(
        x: 200,
        width: 400,
        height: 200,
        leftIsLoss: false,
      );

      expect(zones.loss.left, 200);
      expect(zones.gain.right, 200);
    });

    test(
      'clamps a break-even outside the plot instead of inverting a rect',
      () {
        final left = payoffZones(
          x: -50,
          width: 400,
          height: 200,
          leftIsLoss: true,
        );
        final right = payoffZones(
          x: 900,
          width: 400,
          height: 200,
          leftIsLoss: true,
        );

        expect(left.loss.right, 0);
        expect(right.loss.right, 400);
      },
    );
  });

  group('payoffMarkings', () {
    PayoffMarkings markings({double? breakEvenAt, double? currentAt}) =>
        payoffMarkings(
          points: points,
          width: 400,
          height: 200,
          zeroY: 100,
          priceScale: priceScale,
          valueScale: valueScale,
          breakEvenAt: breakEvenAt,
          currentAt: currentAt,
        );

    test('splits at the break-even when the payload placed one', () {
      final marks = markings(breakEvenAt: 150, currentAt: 175);

      expect(marks.breakEven?.x, 200);
      expect(marks.current?.x, 300);
      expect(marks.loss.right, 200);
      expect(marks.gain.left, 200);
    });

    test('falls back to above and below zero with no break-even', () {
      // The payload the client saw before GGU-146. It must still render, and
      // it must not pretend to a break-even it was not told about.
      final marks = markings(currentAt: 150);

      expect(marks.breakEven, isNull);
      expect(
        marks.loss,
        const ChartRect(left: 0, top: 100, right: 400, bottom: 200),
      );
      expect(
        marks.gain,
        const ChartRect(left: 0, top: 0, right: 400, bottom: 100),
      );
    });
  });
}
