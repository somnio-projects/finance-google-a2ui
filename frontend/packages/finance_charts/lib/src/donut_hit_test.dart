import 'package:finance_charts/src/arctangent.dart';
import 'package:finance_charts/src/donut_layout.dart';

/// Resolving a tap on a donut to the slice under it.
///
/// This is **geometry, so it lives here** and not in the widget (ADR-L D-13):
/// it is a pure function of an offset and a layout, it is asserted
/// arithmetically under `dart test`, and keeping it out of `app/lib/` is what
/// lets it be written without tripping the computation rule.
///
/// The angle comes from [arctangent2], which this package writes out rather
/// than importing — see that file for why, and for the measured defect in the
/// approximation that used to stand here.
extension DonutHitTest on DonutLayout {
  /// The index of the slice at ([dx], [dy]) from the ring's centre, or `null`
  /// when there is nothing to hit.
  ///
  /// Hit testing is by **angle only**, ignoring the radius: a tap in the hole
  /// or just outside the ring still means the reader aimed at the slice in
  /// that direction. The design's ring is 150 px across and only 29 px thick,
  /// so requiring a hit on the band itself would fail the 48 px minimum target
  /// in `.claude/rules/flutter/ui-theming.md`.
  ///
  /// A zero-weight slice can never be the answer: it occupies no angle, and
  /// skipping it is what stops it swallowing the boundary it shares with its
  /// neighbour.
  /// Written as "the last slice that starts at or before this angle" rather
  /// than "the slice whose half-open span contains it". The two agree
  /// everywhere, because the arcs are ordered and together cover the whole
  /// turn — but the first form has no final `else` to fall out of. The span
  /// form needed a fallback for a direction a hair past the last boundary,
  /// which floating-point accumulation can produce and no test can force, and
  /// untestable defensive code is worse than a shape that does not need it.
  int? arcIndexAt(double dx, double dy) {
    if (isEmpty) return null;
    final angle = angleAt(dx, dy);
    // The first slice with any width always starts at twelve o'clock, and
    // `angleAt` never returns less than that, so this is always replaced.
    var found = arcs.first.index;
    for (final arc in arcs) {
      if (arc.sweepAngle > 0 && arc.startAngle <= angle) found = arc.index;
    }
    return found;
  }

  /// The angle of ([dx], [dy]) about the centre, in the arcs' own convention:
  /// radians, clockwise, starting at [twelveOClock].
  ///
  /// `Canvas.drawArc` measures from three o'clock and the canvas' `y` grows
  /// downward, so `arctangent2(dy, dx)` is already clockwise in the right
  /// frame; the only work here is rotating the branch cut to twelve o'clock
  /// so the result is directly comparable with an arc's `startAngle`.
  double angleAt(double dx, double dy) {
    final angle = arctangent2(dy, dx);
    return angle < twelveOClock ? angle + tau : angle;
  }
}
