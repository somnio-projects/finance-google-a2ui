import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group(LinearScale, () {
    test('maps the domain endpoints onto the range endpoints', () {
      const scale = LinearScale(
        domainMin: 0,
        domainMax: 100,
        rangeMin: 200,
        rangeMax: 0,
      );
      expect(scale(0), 200);
      expect(scale(100), 0);
      expect(scale(50), 100);
    });

    test('inverts for a vertical axis, so a larger value is higher', () {
      const scale = LinearScale(
        domainMin: 0,
        domainMax: 10,
        rangeMin: 100,
        rangeMax: 0,
      );
      expect(scale.pixelsPerUnit, -10);
      expect(scale(2), greaterThan(scale(8)));
    });

    test('extrapolates outside the domain rather than clamping', () {
      const scale = LinearScale(
        domainMin: 0,
        domainMax: 10,
        rangeMin: 0,
        rangeMax: 100,
      );
      expect(scale(-1), -10);
      expect(scale(11), 110);
    });

    test('collapses to the range floor when the domain has no span', () {
      const scale = LinearScale(
        domainMin: 5,
        domainMax: 5,
        rangeMin: 200,
        rangeMax: 0,
      );
      expect(scale.pixelsPerUnit, 0);
      expect(scale(5), 200);
    });

    test('is equal to another scale over the same domain and range', () {
      const a = LinearScale(
        domainMin: 0,
        domainMax: 1,
        rangeMin: 0,
        rangeMax: 1,
      );
      const b = LinearScale(
        domainMin: 0,
        domainMax: 1,
        rangeMin: 0,
        rangeMax: 1,
      );
      expect(a, equals(b));
    });

    group('nice', () {
      test('rounds the domain outwards to a readable step', () {
        final scale = LinearScale.nice(
          min: 3,
          max: 47,
          rangeMin: 100,
          rangeMax: 0,
          targetCount: 5,
        );
        expect(scale.domainMin, 0);
        expect(scale.domainMax, 50);
      });

      test('defaults to the interval count the reference design uses', () {
        // Two intervals is the only target that reproduces the catalog
        // page's 478,000 → 484,000 axis; see `specs/frontend/0002`.
        expect(LinearScale.defaultTargetCount, 2);
        final scale = LinearScale.nice(
          min: 479675,
          max: 483685,
          rangeMin: 200,
          rangeMax: 0,
        );
        expect(scale.domainMin, 478000);
        expect(scale.domainMax, 484000);
      });
    });
  });
}
