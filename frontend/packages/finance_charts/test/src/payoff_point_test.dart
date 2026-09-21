import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group('PayoffPoint', () {
    test('compares by both coordinates', () {
      const point = PayoffPoint(at: 152.4, value: 0);
      expect(point, const PayoffPoint(at: 152.4, value: 0));
      expect(point, isNot(const PayoffPoint(at: 152.4, value: 1)));
      expect(point, isNot(const PayoffPoint(at: 106.68, value: 0)));
      expect(point.props, <Object?>[152.4, 0.0]);
    });

    test('describes itself with both coordinates', () {
      expect(
        const PayoffPoint(at: 152.4, value: -150).toString(),
        'PayoffPoint(152.4, -150.0)',
      );
    });
  });

  group('payoffBounds', () {
    test('finds the extent in both domains', () {
      final bounds = payoffBounds(const <PayoffPoint>[
        PayoffPoint(at: 150, value: 0),
        PayoffPoint(at: 100, value: 40),
        PayoffPoint(at: 200, value: -30),
      ]);
      expect(bounds.minAt, 100);
      expect(bounds.maxAt, 200);
      expect(bounds.minValue, -30);
      expect(bounds.maxValue, 40);
    });

    test('answers the sample itself for a curve of one point', () {
      final bounds = payoffBounds(const <PayoffPoint>[
        PayoffPoint(at: 5, value: 7),
      ]);
      expect(bounds.minAt, 5);
      expect(bounds.maxAt, 5);
      expect(bounds.minValue, 7);
      expect(bounds.maxValue, 7);
    });
  });

  group('payoffGridLines', () {
    test('places one line per whole step, ends included', () {
      const scale = LinearScale(
        domainMin: 0,
        domainMax: 100,
        rangeMin: 100,
        rangeMax: 0,
      );
      final lines = payoffGridLines((min: 0.0, max: 100.0, step: 25.0), scale);
      // Five lines for four intervals — the top and the floor both count.
      expect(lines, <double>[100, 75, 50, 25, 0]);
    });
  });
}
