/// A domain rounded outwards to a readable step.
typedef NiceBounds = ({double min, double max, double step});

/// `sqrt(50)`, `sqrt(10)` and `sqrt(2)` as constants.
///
/// These are the thresholds d3's `tickIncrement` uses to choose between a
/// step of 1, 2, 5 or 10 times a power of ten: each is the geometric mean of
/// two neighbouring choices, so the step picked is the one whose *ratio* to
/// the ideal step is smallest. They are written out because `dart:math` is
/// banned from this workspace (`binding_rules_test.dart`) — the ban is about
/// arithmetic on money, and three literals keep this file honest to it rather
/// than arguing for an exemption.
const double _sqrt50 = 7.0710678118654755;
const double _sqrt10 = 3.1622776601683795;
const double _sqrt2 = 1.4142135623730951;

/// The largest power of ten not greater than [value], for `value > 0`.
///
/// This is the base-ten logarithm rounded down, then exponentiated, written
/// as a loop for the reason above. It is exact for the magnitudes a chart
/// axis meets.
double powerOfTen(double value) {
  if (value <= 0) return 1;
  var power = 1.0;
  if (value >= 1) {
    while (power * 10 <= value) {
      power *= 10;
    }
    return power;
  }
  while (power > value) {
    power /= 10;
  }
  return power;
}

/// A readable step that divides [span] into roughly [targetCount] intervals.
///
/// "Readable" means 1, 2, 5 or 10 times a power of ten — the steps a reader
/// can do mental arithmetic on. Returns `0` when [span] is not positive, which
/// [niceBounds] treats as a degenerate domain.
double niceStep(double span, int targetCount) {
  if (span <= 0 || targetCount <= 0) return 0;
  final ideal = span / targetCount;
  final power = powerOfTen(ideal);
  final error = ideal / power;
  if (error >= _sqrt50) return power * 10;
  if (error >= _sqrt10) return power * 5;
  if (error >= _sqrt2) return power * 2;
  return power;
}

/// Rounds `[min, max]` outwards to whole multiples of a readable step.
///
/// This is what gives a chart headroom without anybody choosing a magic
/// padding: the axis ends on a number a reader recognises, and the bars keep
/// their proportions. A degenerate domain (every value equal, or inverted) is
/// widened by one unit either side so the scale never divides by zero.
///
/// [targetCount] is the number of *intervals* aimed for, not ticks.
NiceBounds niceBounds({
  required double min,
  required double max,
  required int targetCount,
}) {
  final step = niceStep(max - min, targetCount);
  if (step <= 0) return (min: min - 1, max: min + 1, step: 1);
  return (
    min: (min / step).floorToDouble() * step,
    max: (max / step).ceilToDouble() * step,
    step: step,
  );
}
