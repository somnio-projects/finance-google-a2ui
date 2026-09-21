import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group(ChartPoint, () {
    test('is equal to another point with the same coordinates', () {
      expect(const ChartPoint(3, 4), equals(const ChartPoint(3, 4)));
      expect(const ChartPoint(3, 4), isNot(equals(const ChartPoint(4, 3))));
    });

    test('describes itself with both coordinates', () {
      expect(const ChartPoint(3, 4).toString(), 'ChartPoint(3.0, 4.0)');
    });
  });

  group(ChartRect, () {
    const rect = ChartRect(left: 10, top: 20, right: 50, bottom: 90);

    test('derives its extents from its edges', () {
      expect(rect.width, 40);
      expect(rect.height, 70);
    });

    test('anchors a value label at the middle of its upper edge', () {
      expect(rect.topCenter, const ChartPoint(30, 20));
    });

    test('between orders the two levels it is given', () {
      // A gain and a loss hand the same two levels in opposite orders; both
      // have to produce a rectangle with a non-negative height, because the
      // painter must never be asked to draw one upside down.
      final rising = ChartRect.between(left: 0, right: 10, a: 90, b: 20);
      final falling = ChartRect.between(left: 0, right: 10, a: 20, b: 90);
      expect(rising, equals(falling));
      expect(rising.top, 20);
      expect(rising.bottom, 90);
      expect(rising.height, 70);
    });

    test('between keeps a zero-height rectangle at its level', () {
      final flat = ChartRect.between(left: 0, right: 10, a: 40, b: 40);
      expect(flat.top, 40);
      expect(flat.bottom, 40);
      expect(flat.height, 0);
    });

    test('is equal to another rectangle with the same edges', () {
      expect(
        rect,
        equals(const ChartRect(left: 10, top: 20, right: 50, bottom: 90)),
      );
      expect(
        rect,
        isNot(equals(const ChartRect(left: 0, top: 20, right: 50, bottom: 90))),
      );
    });

    test('describes itself with all four edges', () {
      expect(rect.toString(), 'ChartRect(10.0, 20.0, 50.0, 90.0)');
    });
  });
}
