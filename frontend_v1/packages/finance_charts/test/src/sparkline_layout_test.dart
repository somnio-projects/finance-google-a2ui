import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group(SparklineLayout, () {
    test('is empty for no values or a degenerate box', () {
      expect(
        SparklineLayout.of(
          values: const <double>[],
          width: 100,
          height: 50,
        ).isEmpty,
        isTrue,
      );
      expect(
        SparklineLayout.of(
          values: const <double>[1],
          width: 0,
          height: 50,
        ).isEmpty,
        isTrue,
      );
      expect(
        SparklineLayout.of(
          values: const <double>[1],
          width: 100,
          height: 0,
        ).isEmpty,
        isTrue,
      );
    });

    test('spreads the values evenly across the width, oldest first', () {
      final layout = SparklineLayout.of(
        values: const <double>[1, 2, 3, 4, 5],
        width: 400,
        height: 52,
      );
      expect(
        layout.points.map((p) => p.x),
        equals(<double>[0, 100, 200, 300, 400]),
      );
    });

    test(
      'puts the smallest value on the bottom edge and the largest on top',
      () {
        final layout = SparklineLayout.of(
          values: const <double>[10, 30, 20],
          width: 200,
          height: 52,
        );
        expect(layout.points[0].y, equals(52));
        expect(layout.points[1].y, equals(0));
        expect(layout.points[2].y, equals(26));
        expect(layout.baseline, equals(52));
      },
    );

    test('draws a flat series at mid-height rather than dividing by zero', () {
      final layout = SparklineLayout.of(
        values: const <double>[7, 7, 7],
        width: 90,
        height: 40,
      );
      expect(layout.points.map((p) => p.y).toSet(), equals(<double>{20}));
    });

    test('places a single value at the left edge', () {
      final layout = SparklineLayout.of(
        values: const <double>[3],
        width: 90,
        height: 40,
      );
      expect(layout.points.single, equals(const ChartPoint(0, 20)));
    });

    test('is a value over its points and baseline', () {
      final a = SparklineLayout.of(
        values: const <double>[1, 2],
        width: 10,
        height: 10,
      );
      final b = SparklineLayout.of(
        values: const <double>[1, 2],
        width: 10,
        height: 10,
      );
      final c = SparklineLayout.of(
        values: const <double>[2, 1],
        width: 10,
        height: 10,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
