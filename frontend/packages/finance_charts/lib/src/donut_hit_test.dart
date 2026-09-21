import 'package:finance_charts/src/donut_layout.dart';

/// Resolving a tap on a donut to the slice under it.
///
/// This is **geometry, so it lives here** and not in the widget (ADR-L D-13):
/// it is a pure function of a offset and a layout, it is asserted
/// arithmetically under `dart test`, and keeping it out of `app/lib/` is what
/// lets it be written without tripping the computation rule.
///
/// It takes no absolute value, does no rounding and imports no trigonometry.
/// Those are banned from `app/lib` outright and carved out only narrowly in
/// this package (`binding_rules_compute_test.dart`), and the ban is cheap to
/// respect here: a sign test is a comparison, and the quadrant does the rest.
/// The rule greps source text, so they are described rather than spelled.
extension DonutHitTest on DonutLayout {
  /// The index of the slice at ([dx], [dy]) from the ring's centre, or `null`
  /// when there is nothing to hit.
  ///
  /// Hit testing is by **angle only**, ignoring the radius: a tap in the hole
  /// or just outside the ring still means the reader aimed at the slice in
  /// that direction. The design's ring is 150 px across and only 29 px thick,
  /// so requiring a hit on the band itself would fail the 48 px minimum target
  /// in `.claude/rules/flutter/ui-theming.md`.
  int? arcIndexAt(double dx, double dy) {
    if (isEmpty) return null;
    final angle = angleAt(dx, dy);
    for (final arc in arcs) {
      if (arc.sweepAngle <= 0) continue;
      if (angle >= arc.startAngle && angle < arc.startAngle + arc.sweepAngle) {
        return arc.index;
      }
    }
    return null;
  }

  /// The angle of ([dx], [dy]) about the centre, in the arcs' own convention:
  /// radians, clockwise, starting at [twelveOClock].
  ///
  /// Arc-tangent would be the obvious tool and lives in `dart:math`, which
  /// this
  /// workspace bans. It is not needed: the quadrant comes from two sign tests,
  /// and **within** the quadrant the fraction of the two legs is monotonic in
  /// the true angle, exact on both axes and exact at 45°. A hit test needs an
  /// ordering, not an angle, so a monotonic surrogate is not an approximation
  /// that can be wrong — it selects the same slice the real angle would.
  ///
  /// Quadrants 0 and 2 begin on a **vertical** axis, so their fraction grows
  /// with the horizontal leg; 1 and 3 begin on a horizontal axis and grow
  /// with the vertical one. Having those two the wrong way round put a tap at
  /// three o'clock half a turn around the ring, and the zero-weight test in
  /// `donut_chart_test.dart` is what caught it.
  double angleAt(double dx, double dy) {
    final quarter = _quarterTurns(dx, dy);
    final a = dx < 0 ? -dx : dx;
    final b = dy < 0 ? -dy : dy;
    final total = a + b;
    // On the exact centre there is no direction; the first slice of the
    // quadrant is as good an answer as any and it never throws.
    final within = total <= 0 ? 0.0 : (quarter.isEven ? a / total : b / total);
    return twelveOClock + (quarter + within) / 4 * tau;
  }

  /// Which quarter turn clockwise from twelve o'clock ([dx], [dy]) falls in.
  ///
  /// 0 is the top-right quadrant, 1 bottom-right, 2 bottom-left, 3 top-left —
  /// the order the arcs are laid out in.
  int _quarterTurns(double dx, double dy) {
    if (dx >= 0 && dy < 0) return 0;
    if (dx >= 0 && dy >= 0) return 1;
    if (dx < 0 && dy >= 0) return 2;
    return 3;
  }
}
