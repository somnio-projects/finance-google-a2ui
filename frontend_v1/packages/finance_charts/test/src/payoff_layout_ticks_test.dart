import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../payoff_reference.dart';

/// The layout's *identity* and its *tick lookup*, split from the suite over
/// its arithmetic so both stay inside the 150-line budget.
void main() {
  PayoffLayout at(double width) => PayoffLayout.of(
    series: const <List<PayoffPoint>>[designCurve],
    width: width,
    height: designPlotHeight,
  );

  group('PayoffLayout equality', () {
    test('is equal to another layout over the same inputs', () {
      expect(at(designPlotWidth), at(designPlotWidth));
      expect(at(designPlotWidth).hashCode, at(designPlotWidth).hashCode);
    });

    test('differs once the plot is a different width', () {
      // The width reaches every path coordinate and both regions, so this is
      // also what makes a resize repaint rather than reuse a stale raster.
      expect(at(designPlotWidth), isNot(at(designPlotWidth / 2)));
    });
  });

  group('PayoffLayout.tickX', () {
    test('answers the x of a point in range', () {
      expect(at(designPlotWidth).tickX(0), closeTo(0, 1e-9));
      expect(
        at(designPlotWidth).tickX(designCurve.length - 1),
        closeTo(designPlotWidth, 1e-9),
      );
    });

    test('answers null past either end of the series', () {
      expect(at(designPlotWidth).tickX(-1), isNull);
      expect(at(designPlotWidth).tickX(designCurve.length), isNull);
    });

    test('answers null for a series that is not there', () {
      expect(at(designPlotWidth).tickX(0, seriesIndex: 1), isNull);
      expect(at(designPlotWidth).tickX(0, seriesIndex: -1), isNull);
    });
  });
}
