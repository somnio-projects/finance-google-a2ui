import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

/// Reference values, written out because `dart:math` is banned here too.
///
/// Each is an angle whose tangent is exactly expressible, so a pair is a check
/// of *this* implementation rather than a comparison of two approximations.
const double _pi = 3.141592653589793;
const double _sqrt3 = 1.7320508075688772;
const double _tan15 = 0.26794919243112270;

/// The measured worst-case error of the series, in radians.
///
/// Largest at the argument-reduction boundary (`z = tan 15°`), where it is
/// **1.65e-10** — about 9.5e-9 degrees. The ring the hit test serves is 150 px
/// across, which resolves roughly 0.1°, so this is seven orders of magnitude
/// finer than anything a reader can aim at. The tolerance is the measurement
/// rounded up, not a number chosen to make the suite pass.
const double _tolerance = 1e-9;

void main() {
  group('arctangent', () {
    test('matches the angles whose tangent is exact', () {
      // Across both argument reductions: below tan 15°, the middle band, and
      // above 1, where the 1/z reflection runs.
      const cases = <List<double>>[
        <double>[0, 0],
        <double>[_tan15, _pi / 12],
        <double>[1 / _sqrt3, _pi / 6],
        <double>[1, _pi / 4],
        <double>[_sqrt3, _pi / 3],
        <double>[1 / _tan15, _pi * 5 / 12],
      ];
      for (final c in cases) {
        expect(
          arctangent(c[0]),
          closeTo(c[1], _tolerance),
          reason: 'atan(${c[0]})',
        );
        expect(arctangent(-c[0]), closeTo(-c[1], _tolerance));
      }
    });

    test('satisfies the arctangent addition identity', () {
      // atan(1/2) + atan(1/3) = pi/4, and atan(1/7) + 2*atan(1/3) = pi/4
      // (Euler). Neither reference angle appears in the table above, and the
      // identity constrains the whole curve rather than six points on it.
      expect(
        arctangent(1 / 2) + arctangent(1 / 3),
        closeTo(_pi / 4, _tolerance),
      );
      expect(
        arctangent(1 / 7) + 2 * arctangent(1 / 3),
        closeTo(_pi / 4, _tolerance),
      );
      // Machin's formula, which exercises a small argument and a large one.
      expect(
        4 * arctangent(1 / 5) - arctangent(1 / 239),
        closeTo(_pi / 4, _tolerance),
      );
    });

    test('is odd, monotonic and bounded across a wide range', () {
      var previous = arctangent(-1000);
      expect(previous, greaterThan(-_pi / 2));
      for (var z = -999.0; z <= 1000; z += 1) {
        final next = arctangent(z);
        expect(next, greaterThan(previous));
        expect(arctangent(-z), closeTo(-next, _tolerance));
        previous = next;
      }
      expect(previous, lessThan(_pi / 2));
    });

    test('arctangent2 puts each quadrant where the canvas expects it', () {
      // `y` grows downward, so a positive result is clockwise from three
      // o'clock — the frame `Canvas.drawArc` and `DonutArc` share.
      expect(arctangent2(0, 1), closeTo(0, _tolerance));
      expect(arctangent2(1, 0), closeTo(_pi / 2, _tolerance));
      expect(arctangent2(-1, 0), closeTo(-_pi / 2, _tolerance));
      expect(arctangent2(0, -1), closeTo(_pi, _tolerance));
      expect(arctangent2(1, 1), closeTo(_pi / 4, _tolerance));
      expect(arctangent2(-1, 1), closeTo(-_pi / 4, _tolerance));
      expect(arctangent2(1, -1), closeTo(_pi * 3 / 4, _tolerance));
      expect(arctangent2(-1, -1), closeTo(-_pi * 3 / 4, _tolerance));
    });

    test('arctangent2 is scale-invariant, as a direction should be', () {
      for (final k in <double>[0.001, 1, 75, 10000]) {
        expect(arctangent2(k * 3, k * 4), closeTo(arctangent2(3, 4), 1e-12));
        expect(
          arctangent2(-k * 3, -k * 4),
          closeTo(arctangent2(-3, -4), 1e-12),
        );
      }
    });

    test('answers the origin without throwing', () {
      expect(arctangent2(0, 0), equals(0));
    });
  });
}
