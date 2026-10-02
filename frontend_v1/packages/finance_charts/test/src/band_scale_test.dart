import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group(BandScale, () {
    test('splits the width into equal bands', () {
      const scale = BandScale(count: 4, width: 400);
      expect(scale.bandWidth, 100);
      expect(scale.center(0), 50);
      expect(scale.center(3), 350);
    });

    test('has no band when there is nothing to lay out', () {
      // An empty walk still produces a scale; it must not divide by zero.
      const scale = BandScale(count: 0, width: 400);
      expect(scale.bandWidth, 0);
      expect(scale.bandAt(10), isNull);
    });

    test('widens a bar with its band until the cap', () {
      // The narrow artboard: 244.70 px over seven bands, bars measured at
      // 21.7 px — the ratio below the cap.
      const narrow = BandScale(count: 7, width: 244.70);
      expect(narrow.barWidth, closeTo(21.68, 0.02));
      // The wide artboard: 533.37 px, where the ratio would give 47.2 px and
      // the design draws 44.0 px.
      const wide = BandScale(count: 7, width: 533.37);
      expect(wide.barWidth, 44);
    });

    test('centres the bar in its band', () {
      const scale = BandScale(count: 2, width: 200, maxBarWidth: 40);
      expect(scale.barLeft(0), 30);
      expect(scale.barRight(0), 70);
      expect(scale.barRight(0) - scale.barLeft(0), scale.barWidth);
    });

    test('hit tests by band, not by bar', () {
      // A tap in the gutter still means the reader aimed at that step; the
      // bar itself can be under the 48 px minimum touch target.
      const scale = BandScale(count: 4, width: 400);
      expect(scale.bandAt(0), 0);
      expect(scale.bandAt(99), 0);
      expect(scale.bandAt(100), 1);
      expect(scale.bandAt(399), 3);
    });

    test('reports no band outside the plot', () {
      const scale = BandScale(count: 4, width: 400);
      expect(scale.bandAt(-1), isNull);
      expect(scale.bandAt(400), isNull);
      expect(scale.bandAt(1000), isNull);
    });

    test('clamps a rounding overshoot to the last band', () {
      // `width / bandWidth` can land exactly on `count` for some widths;
      // the guard keeps the index inside the list the caller will index.
      const scale = BandScale(count: 3, width: 0.30000000000000004);
      expect(scale.bandAt(0.29999999999999993), lessThan(3));
    });

    test('is equal to another scale with the same shape', () {
      expect(
        const BandScale(count: 7, width: 100),
        equals(const BandScale(count: 7, width: 100)),
      );
    });
  });
}
