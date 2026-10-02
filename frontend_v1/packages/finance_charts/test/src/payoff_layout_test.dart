import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../payoff_reference.dart';

void main() {
  group('PayoffLayout.of', () {
    test('maps the price domain edge to edge', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      // The design's own scaleX puts the first sample on the left edge of the
      // plot and the last on the right: a payoff curve is sampled on a grid
      // the backend chose, so the axis is the data's range and not a rounding
      // of it.
      expect(layout.paths.single.first.x, closeTo(0, 1e-9));
      expect(layout.paths.single.last.x, closeTo(designPlotWidth, 1e-9));
    });

    test("places every point where the design's scales put it", () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      for (final (index, point) in designCurve.indexed) {
        expect(
          layout.paths.single[index].x,
          closeTo(designScaleX(point.at), 1e-6),
          reason: 'x of sample $index (at ${point.at})',
        );
      }
    });

    test('puts zero on the value scale, not at a crossing in the data', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      // AC-3: the baseline is `valueScale(0)`. Asserted against the scale
      // rather than against a sample, because no sample need sit on zero —
      // and the component must never go looking for one (ticket AC-2, OD-1).
      expect(layout.zeroY, closeTo(layout.valueScale(0), 1e-12));
      expect(layout.lossRegion.top, layout.zeroY);
      expect(layout.gainRegion.bottom, layout.zeroY);
      expect(layout.lossRegion.bottom, designPlotHeight);
      expect(layout.gainRegion.top, 0);
    });

    test('rounds the value axis outwards to a readable step', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      // The data spans -2,400 to 18,480; five intervals of that span round to
      // a step of 5,000, so the axis runs -5,000 to 20,000 and every gridline
      // lands on a number a reader recognises.
      expect(layout.valueScale.domainMin, -5000);
      expect(layout.valueScale.domainMax, 20000);
      expect(layout.gridLines, hasLength(6));
    });

    test('a larger value is a smaller y', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      final path = layout.paths.single;
      expect(path.last.y, lessThan(path.first.y));
      expect(layout.valueScale(-2400), greaterThan(layout.zeroY));
      expect(layout.valueScale(5880), lessThan(layout.zeroY));
    });

    test('lays out a second series without moving the first', () {
      final one = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      final two = PayoffLayout.of(
        series: const <List<PayoffPoint>>[designCurve, designCurve],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      expect(two.paths, hasLength(2));
      expect(two.paths.first, one.paths.single);
      expect(two.paths.last, one.paths.single);
    });

    test('widens a domain of one sample rather than dividing by zero', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[
          <PayoffPoint>[PayoffPoint(at: 152.4, value: 0)],
        ],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      expect(layout.priceScale.domainMax, 153.4);
      expect(layout.paths.single.single.x, closeTo(0, 1e-9));
    });

    test('renders an empty plot for a payload with no series', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      expect(layout.paths, isEmpty);
      expect(layout.gridLines, isEmpty);
      expect(layout.zeroY, designPlotHeight);
    });

    test('renders an empty plot for a series with no points', () {
      final layout = PayoffLayout.of(
        series: const <List<PayoffPoint>>[<PayoffPoint>[]],
        width: designPlotWidth,
        height: designPlotHeight,
      );
      expect(layout.paths, isEmpty);
    });
  });
}
