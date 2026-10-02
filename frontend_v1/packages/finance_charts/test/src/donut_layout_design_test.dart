import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../donut_design_reference.dart';

/// Where [arc] ends, in CSS degrees clockwise from twelve o'clock.
///
/// The design expresses the ring as a `conic-gradient(from 0deg, …)`; this
/// puts a [DonutArc] in the same units so the two can be compared directly
/// rather than by eye.
double endDegrees(DonutArc arc) =>
    (arc.startAngle + arc.sweepAngle - twelveOClock) / tau * 360;

void main() {
  group('DonutLayout against the design', () {
    test("reproduces the design's by-class gradient stops", () {
      // The measurement that makes this a check of *the design* rather than
      // of itself: four slices, four stops, read off the rendered page.
      final layout = DonutLayout.of(
        weights: designClassWeights,
        width: designOuterDiameter,
        height: designOuterDiameter,
      );
      expect(layout.arcs, hasLength(designClassStops.length));
      for (var i = 0; i < designClassStops.length; i++) {
        expect(
          endDegrees(layout.arcs[i]),
          closeTo(designClassStops[i], 0.01),
          reason: "slice $i ends at the design's stop",
        );
      }
    });

    test("reproduces the design's by-sector gradient stops", () {
      final layout = DonutLayout.of(
        weights: designSectorWeights,
        width: designSecondaryOuterDiameter,
        height: designSecondaryOuterDiameter,
      );
      for (var i = 0; i < designSectorStops.length; i++) {
        expect(endDegrees(layout.arcs[i]), closeTo(designSectorStops[i], 0.01));
      }
    });
  });
}
