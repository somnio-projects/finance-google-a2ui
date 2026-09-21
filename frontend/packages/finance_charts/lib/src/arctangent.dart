/// Arctangent, written out rather than imported.
///
/// `dart:math` is banned from this workspace (`binding_rules_test.dart`), and
/// this file is the same bargain `tick_steps.dart` already makes for three
/// square roots: *"the ban is about arithmetic on money, and three literals
/// keep this file honest to it rather than arguing for an exemption."* An
/// arctangent is a few more lines than a literal, so the reasoning is spelled
/// out here instead of assumed.
///
/// **Why it exists at all.** A donut's hit test has to turn an offset into an
/// angle to decide which slice was tapped. The first attempt avoided this with
/// a monotonic surrogate — the quadrant, plus the ratio of the two legs within
/// it — on the argument that "a hit test needs an ordering, not an angle".
/// **That argument was wrong, and measurably so.** Monotonicity orders two
/// surrogate values against each other; it says nothing about whether a
/// surrogate value lands in the same interval as the true angle, and the arc
/// boundaries it was compared against are true radians
/// (`weight / total * tau`). Measured on the catalog's own example payload:
/// the wrong slice for **1259 of 36000 directions (3.50 %)**, worst angular
/// error **4.075°** — against a smallest slice of 2.35 %, which is 8.5° wide.
/// Every test that existed used layouts whose boundaries fell on an axis,
/// which is exactly where the surrogate is exact, so none of them could have
/// gone red.
///
/// The alternative was a named `dart:math` carve-out for the hit-test file.
/// It was rejected because the allow-list in `binding_rules_test.dart` is
/// asserted to have exactly one member, and that claim is repeated in ADR-L
/// D-14, in two rule files and in `SECURITY.md` — widening it for a tap target
/// would be a large blast radius for a small need. `specs/frontend/0007` §4
/// records the choice.
library;

/// A full turn, in radians. Re-exported from the layout for callers here.
const double _pi = 3.141592653589793;

/// A quarter turn, in radians.
const double _piOver2 = 1.5707963267948966;

/// A twelfth of a turn, in radians — the angle the reduction below subtracts.
const double _piOver6 = 0.5235987755982988;

/// `tan(15°)`, the largest argument the series is evaluated at.
const double _tan15 = 0.26794919243112270;

/// `sqrt(3)`, for the argument reduction. Written out for the same reason
/// `tick_steps.dart` writes out its three roots.
const double _sqrt3 = 1.7320508075688772;

/// `atan(w)` by its Taylor series, for `|w| <= tan(15°)`.
///
/// Seven terms. The first omitted term is `w¹⁵/15`, which at the largest
/// argument the reduction can produce is under `1e-9` — four orders of
/// magnitude finer than the tenth of a degree a 150 px ring can resolve.
double _atanSeries(double w) {
  final w2 = w * w;
  return w *
      (1 +
          w2 *
              (-1 / 3 +
                  w2 *
                      (1 / 5 +
                          w2 *
                              (-1 / 7 +
                                  w2 *
                                      (1 / 9 +
                                          w2 * (-1 / 11 + w2 * (1 / 13)))))));
}

/// `atan(z)` for any `z`, in radians, in `(-π/2, π/2)`.
///
/// Two reductions bring every argument into the series' fast range: `z → 1/z`
/// for `|z| > 1` (which reflects about the 45° diagonal), then
/// `atan(z) = π/6 + atan((z√3 − 1) / (z + √3))` for the rest, which maps
/// `(tan 15°, 1]` onto `[−tan 15°, tan 15°]` exactly.
double arctangent(double z) {
  if (z < 0) return -arctangent(-z);
  if (z > 1) return _piOver2 - arctangent(1 / z);
  if (z > _tan15) {
    return _piOver6 + _atanSeries((z * _sqrt3 - 1) / (z + _sqrt3));
  }
  return _atanSeries(z);
}

/// The angle of the vector ([x], [y]) from the positive x axis, in `(-π, π]`.
///
/// The canvas convention, so `y` grows **downward** and a positive result is
/// clockwise — which is the same convention `Canvas.drawArc` and therefore
/// `DonutArc` use, so no caller converts anything.
double arctangent2(double y, double x) {
  if (x > 0) return arctangent(y / x);
  if (x < 0) return y < 0 ? arctangent(y / x) - _pi : arctangent(y / x) + _pi;
  if (y > 0) return _piOver2;
  if (y < 0) return -_piOver2;
  // The exact centre has no direction. Zero is as good an answer as any, it
  // never throws, and the hit test resolves it to whichever slice covers
  // three o'clock.
  return 0;
}
