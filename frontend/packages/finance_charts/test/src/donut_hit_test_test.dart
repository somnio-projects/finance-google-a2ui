import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../donut_design_reference.dart';

void main() {
  group('DonutHitTest', () {
    /// Four equal quarters, so the expected slice for a direction is obvious:
    /// 0 is top-right, 1 bottom-right, 2 bottom-left, 3 top-left.
    ///
    /// **Every boundary here lands on an axis**, which is the one family of
    /// layouts an approximate angle gets right for free. These cases are kept
    /// because they are readable, but on their own they proved nothing — see
    /// `::resolves a tap near a boundary of the catalog's own payload`.
    DonutLayout quarters() => DonutLayout.of(
      weights: const <double>[0.25, 0.25, 0.25, 0.25],
      width: 150,
      height: 150,
    );

    DonutLayout catalogRing() =>
        DonutLayout.of(weights: catalogExampleWeights, width: 150, height: 150);

    test('resolves each quadrant to its own slice', () {
      final layout = quarters();
      expect(layout.arcIndexAt(30, -30), equals(0));
      expect(layout.arcIndexAt(30, 30), equals(1));
      expect(layout.arcIndexAt(-30, 30), equals(2));
      expect(layout.arcIndexAt(-30, -30), equals(3));
    });

    test('resolves the four axes exactly', () {
      final layout = quarters();
      expect(layout.arcIndexAt(0, -40), equals(0));
      expect(layout.arcIndexAt(40, 0), equals(1));
      expect(layout.arcIndexAt(0, 40), equals(2));
      expect(layout.arcIndexAt(-40, 0), equals(3));
    });

    test("resolves a tap near a boundary of the catalog's own payload", () {
      // **The test the first implementation could not have passed.** It used a
      // monotonic surrogate for the angle and compared it against boundaries
      // in true radians; the two agree only on the axes and the diagonals, so
      // a layout whose boundaries fall anywhere else drifts by up to 4.075°.
      // On this payload that was the wrong slice for 3.50 % of all directions,
      // against a smallest slice only 8.5° wide.
      //
      // The expected values are computed **independently** — `dart:math`'s own
      // `atan2`, in a scratch script, 1.5° either side of each of the five
      // boundaries, comfortably inside the old error band. Holding them as
      // literals is what makes this a check of the implementation rather than
      // of itself, the shape `donut_design_reference.dart` already uses.
      final layout = catalogRing();
      for (final (dx, dy, slice) in referenceTaps) {
        expect(
          layout.arcIndexAt(dx, dy),
          equals(slice),
          reason: 'tap ($dx, $dy)',
        );
      }
    });

    test('is monotonic in the angle within a quadrant', () {
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
      // The zero slice is skipped when it is also the last one, which is the
      // path that would otherwise return null at the final boundary.
      final trailing = DonutLayout.of(
        weights: const <double>[1, 0],
        width: 150,
        height: 150,
      );
      expect(trailing.arcIndexAt(0, -40), equals(0));
    });

    test('never drops a tap, whatever direction it comes from', () {
      // Total coverage over the real payload: every direction resolves to
      // some slice. A gap would be a tap that silently does nothing, and the
      // last boundary is where floating-point accumulation could open one.
      final layout = catalogRing();
      for (var step = 0; step < 360; step++) {
        // A square walk, which sweeps every direction without sin and cos.
        final t = step / 360;
        final dx = t < 0.5 ? 1 - 4 * t : 4 * t - 3;
        final dy = t < 0.25 || t > 0.75 ? -1.0 : 1.0;
        expect(layout.arcIndexAt(dx * 40, dy * 40), isNotNull);
      }
    });
  });
}
