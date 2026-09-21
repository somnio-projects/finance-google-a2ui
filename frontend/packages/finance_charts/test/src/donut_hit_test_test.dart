import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group('DonutHitTest', () {
    /// Four equal quarters, so the expected slice for a direction is obvious:
    /// 0 is top-right, 1 bottom-right, 2 bottom-left, 3 top-left.
    DonutLayout quarters() => DonutLayout.of(
      weights: const <double>[0.25, 0.25, 0.25, 0.25],
      width: 150,
      height: 150,
    );

    test('resolves each quadrant to its own slice', () {
      final layout = quarters();
      expect(layout.arcIndexAt(30, -30), equals(0));
      expect(layout.arcIndexAt(30, 30), equals(1));
      expect(layout.arcIndexAt(-30, 30), equals(2));
      expect(layout.arcIndexAt(-30, -30), equals(3));
    });

    test('resolves the four axes exactly', () {
      // The surrogate is exact on the axes, which is where an off-by-one
      // between neighbouring slices would first show.
      final layout = quarters();
      expect(layout.arcIndexAt(0, -40), equals(0));
      expect(layout.arcIndexAt(40, 0), equals(1));
      expect(layout.arcIndexAt(0, 40), equals(2));
      expect(layout.arcIndexAt(-40, 0), equals(3));
    });

    test('is monotonic in the angle within a quadrant', () {
      // The property the surrogate has to have: sweeping clockwise through a
      // quadrant never goes backwards. That is what makes it safe to use in
      // place of `atan2`, which `dart:math` would otherwise be needed for.
      final layout = quarters();
      var previous = layout.angleAt(0, -40);
      for (var step = 1.0; step <= 40; step++) {
        final next = layout.angleAt(step, -40);
        expect(next, greaterThanOrEqualTo(previous));
        previous = next;
      }
    });

    test('answers the direction regardless of distance from the centre', () {
      // Hit testing ignores the radius on purpose: a tap in the hole, on the
      // band, or outside the ring all mean the same slice.
      final layout = quarters();
      for (final radius in <double>[1, 20, 46, 75, 400]) {
        expect(layout.arcIndexAt(radius, -radius), equals(0));
      }
    });

    test('answers the exact centre without throwing', () {
      expect(quarters().arcIndexAt(0, 0), equals(1));
    });

    test('has nothing to hit on an empty portfolio', () {
      final empty = DonutLayout.of(
        weights: const <double>[],
        width: 150,
        height: 150,
      );
      expect(empty.arcIndexAt(10, 10), isNull);
    });

    test('skips a zero-weight slice', () {
      // A category the backend sent with a zero share occupies no angle, so
      // it can never be the answer — but it must not shift its neighbours.
      final layout = DonutLayout.of(
        weights: const <double>[0.5, 0, 0.5],
        width: 150,
        height: 150,
      );
      expect(layout.arcIndexAt(30, -30), equals(0));
      expect(layout.arcIndexAt(-30, 30), equals(2));
      expect(layout.arcs[1].sweepAngle, isZero);
    });

    test('lands inside a slice for every direction of a full ring', () {
      // Total coverage: sweeping the whole turn, every direction resolves to
      // some slice. A gap would be a tap that silently does nothing.
      final layout = quarters();
      for (var step = 0; step < 72; step++) {
        final turns = step / 72;
        // Two straight lines around the square, which covers every direction
        // without needing sin and cos.
        final dx = turns < 0.5 ? 1 - 4 * turns : 4 * turns - 3;
        final dy = turns < 0.25 || turns > 0.75 ? -1.0 : 1.0;
        expect(layout.arcIndexAt(dx * 40, dy * 40), isNotNull);
      }
    });
  });
}
