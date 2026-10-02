import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/chart_geometry.dart';

/// A full turn, in radians.
///
/// Written out because `dart:math` is banned from this workspace
/// (`binding_rules_test.dart`) — the same arrangement `tick_steps.dart` makes
/// for its three square roots. The ban is about arithmetic on money, and one
/// literal keeps this file honest to it rather than arguing for an exemption.
const double tau = 6.283185307179586;

/// Twelve o'clock, in the canvas' angle convention.
///
/// `Canvas.drawArc` measures from three o'clock and sweeps clockwise, so the
/// top of the ring is a quarter turn back. The design's ring starts at the
/// top: its CSS is `conic-gradient(from 0deg, …)`, whose zero **is** twelve
/// o'clock, and the rendered stops confirm it (the first slice of the
/// by-class donut runs `0deg → 223.2deg`). Converting that convention to the
/// canvas' is this constant, and it is not a value anybody tunes per chart.
const double twelveOClock = -tau / 4;

/// One slice of a donut: where it starts and how far it sweeps.
///
/// Angles are radians in `Canvas.drawArc`'s convention — clockwise, zero at
/// three o'clock — so the painter converts nothing.
class DonutArc extends Equatable {
  /// Creates an arc.
  const DonutArc({
    required this.index,
    required this.startAngle,
    required this.sweepAngle,
  });

  /// The category's position in the payload's `categories`, which is also its
  /// position in the legend and the swatch it is given (N-10).
  final int index;

  /// Where the slice begins.
  final double startAngle;

  /// How far it runs. Never negative; a category with a zero weight gets a
  /// zero sweep rather than being dropped, so arc *i* is always category *i*.
  final double sweepAngle;

  @override
  List<Object?> get props => <Object?>[index, startAngle, sweepAngle];

  @override
  String toString() => 'DonutArc($index, $startAngle, $sweepAngle)';
}

/// The complete geometry of a donut chart: *(weights, size) → arcs*.
///
/// The second primitive in this package and the same bargain as the first
/// (ADR-L D-13): a pure value, so "is the Bitcoin slice 59 % of the ring" is
/// asserted arithmetically under `dart test` instead of eyeballed in a
/// screenshot. The weights arrive as raw `weight.value` members through the
/// one number seam (ADR-L D-14) and become angles here; they never become a
/// string, and the `weight.display` string never becomes an angle.
class DonutLayout extends Equatable {
  const DonutLayout._({
    required this.arcs,
    required this.center,
    required this.outerRadius,
    required this.innerRadius,
  });

  /// Lays [weights] out on a plot of [width] × [height] pixels.
  ///
  /// Sweeps are proportional to each weight's share of their **sum**, not to
  /// the weight itself. The contract says the weights sum to one, and a
  /// layout that trusts that leaves a hairline gap whenever the backend's
  /// rounding lands at 0.9999 — normalising is what a scale does with its
  /// domain, and it is the difference between a ring that closes and one that
  /// nearly does. The design does the same arithmetic in CSS degrees
  /// (`acc * 3.6`, on weights that are percentages).
  ///
  /// A non-positive total — an empty portfolio, or a plot with no room —
  /// yields no arcs. The caller renders the payload's own empty state; it
  /// does not draw a ring with nothing in it.
  factory DonutLayout.of({
    required List<double> weights,
    required double width,
    required double height,
    double thicknessRatio = defaultThicknessRatio,
  }) {
    final shorter = width < height ? width : height;
    final outer = shorter <= 0 ? 0.0 : shorter / 2;
    return DonutLayout._(
      arcs: _arcs(weights),
      center: ChartPoint(width / 2, height / 2),
      outerRadius: outer,
      innerRadius: outer * thicknessRatio,
    );
  }

  /// The hole's radius as a fraction of the ring's, which is what makes this
  /// a donut rather than a pie.
  ///
  /// **Measured from Miriam's Figma** (GGU-145): the `HoldingsSummary`
  /// artboard draws a 160 px ring with a 135 px hole, written as those two
  /// numbers rather than the decimal they produce.
  /// It was `92 / 150` until 2026-09-28, from `.design-refs/*.dc.html` — a
  /// catalog mock this repository generated, not a design export (spec
  /// `frontend/0031` § 2). They disagree a lot — 0.613 against 0.844 — and the
  /// mock's fat ring overflowed the design's own total when GGU-145 moved it
  /// into the centre.
  static const double defaultThicknessRatio = 135 / 160;

  /// One arc per weight, in the order the backend sent them.
  final List<DonutArc> arcs;

  /// The ring's centre in the plot's coordinate space.
  final ChartPoint center;

  /// The ring's outer edge.
  final double outerRadius;

  /// The hole's edge.
  final double innerRadius;

  /// Whether there is anything to draw.
  bool get isEmpty => arcs.isEmpty;

  /// The ring's painted thickness, which is also the stroke a painter uses.
  double get thickness => outerRadius - innerRadius;

  /// The radius the stroke is centred on, between the two edges.
  double get strokeRadius => (outerRadius + innerRadius) / 2;

  @override
  List<Object?> get props => <Object?>[arcs, center, outerRadius, innerRadius];

  static List<DonutArc> _arcs(List<double> weights) {
    var total = 0.0;
    for (final weight in weights) {
      if (weight > 0) total += weight;
    }
    if (total <= 0) return const <DonutArc>[];
    final arcs = <DonutArc>[];
    var cursor = twelveOClock;
    for (var index = 0; index < weights.length; index++) {
      final weight = weights[index];
      final sweep = weight > 0 ? weight / total * tau : 0.0;
      arcs.add(DonutArc(index: index, startAngle: cursor, sweepAngle: sweep));
      cursor += sweep;
    }
    return arcs;
  }
}
