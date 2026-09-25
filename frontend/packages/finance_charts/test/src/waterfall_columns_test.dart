import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

/// The two pieces of arithmetic the UI Kit's waterfall added (spec
/// frontend/0028): the band column its selected state tints, and the clamp
/// that keeps a total's figure inside the plot instead of dropping it.
///
/// Asserted against numbers rather than a raster, for the reason ADR-L D-13
/// gives: a golden says something moved, these say what.
void main() {
  group('waterfallColumn', () {
    // Seven bands over 700 px is a 100 px band, which makes every edge below
    // readable without a calculator.
    const band = BandScale(count: 7, width: 700);

    test('spans its whole band, floor to ceiling', () {
      final column = waterfallColumn(band, 2, height: 200);
      expect(column.left, 200);
      expect(column.right, 300);
      expect(column.top, 0);
      expect(column.bottom, 200);
      expect(column.width, band.bandWidth);
    });

    test('is wider than the bar it stands behind', () {
      // The design tints the band, not the bar: at a 0.62 ratio the bar is
      // 44 px (the cap) inside a 100 px band, so the tint shows on both
      // sides. A column equal to the bar would read as a recolour.
      final column = waterfallColumn(band, 0, height: 200);
      expect(band.barRight(0) - band.barLeft(0), lessThan(column.width));
    });

    test('tiles the plot with no gap and no overlap', () {
      for (var index = 0; index < band.count - 1; index++) {
        expect(
          waterfallColumn(band, index, height: 10).right,
          waterfallColumn(band, index + 1, height: 10).left,
        );
      }
      expect(waterfallColumn(band, band.count - 1, height: 10).right, 700);
    });

    test('collapses to nothing when there are no bands', () {
      // `bandWidth` is 0 for an empty walk; the column must not be a
      // division by that emptiness.
      const empty = BandScale(count: 0, width: 700);
      final column = waterfallColumn(empty, 0, height: 200);
      expect(column.width, 0);
    });
  });

  group('clampedLabelLeft', () {
    test('centres a label that fits', () {
      expect(clampedLabelLeft(center: 350, width: 60, plotWidth: 700), 320);
    });

    test('pushes a label off the left edge back to it', () {
      // The opening total's figure is wider than its own band: centred it
      // would start at -10 and lose its currency symbol.
      expect(clampedLabelLeft(center: 20, width: 60, plotWidth: 700), 0);
    });

    test('pulls a label off the right edge back inside', () {
      // `$482,915` over the closing bar: centred at 690 it would end at 720.
      expect(clampedLabelLeft(center: 690, width: 60, plotWidth: 700), 640);
      expect(
        clampedLabelLeft(center: 690, width: 60, plotWidth: 700) + 60,
        700,
      );
    });

    test('leaves a label exactly at an edge alone', () {
      expect(clampedLabelLeft(center: 30, width: 60, plotWidth: 700), 0);
      expect(clampedLabelLeft(center: 670, width: 60, plotWidth: 700), 640);
    });

    test('pins a label wider than the plot to the left edge', () {
      // Nothing can be centred at that width, and a negative start would
      // hide the beginning of the figure, which is the part that carries
      // the sign and the currency.
      expect(clampedLabelLeft(center: 350, width: 800, plotWidth: 700), 0);
      expect(clampedLabelLeft(center: 350, width: 700, plotWidth: 700), 0);
    });
  });

  group('clampedOverlayTop', () {
    test('sits the callout a gap above a bar with room for it', () {
      expect(
        clampedOverlayTop(barTop: 120, height: 80, gap: 6, plotHeight: 200),
        34,
      );
    });

    test('pushes a callout with no room above down to the ceiling', () {
      // The defect this exists for: a walk whose peak bar tops out 38 px
      // down leaves 32 px above it for an 80 px callout, so the ideal `y`
      // is -48 and the card's clip takes the name off the top.
      expect(
        clampedOverlayTop(barTop: 38, height: 80, gap: 6, plotHeight: 200),
        0,
      );
    });

    test('never returns a negative top, for any bar in a real walk', () {
      // Universally quantified: the clip is what turns a negative top into a
      // visible defect, so what has to hold is the *sign*, at every bar.
      for (final barTop in <double>[0, 1, 37.5, 60, 120, 199]) {
        for (final height in <double>[40, 80, 140]) {
          expect(
            clampedOverlayTop(
              barTop: barTop,
              height: height,
              gap: 6,
              plotHeight: 200,
            ),
            greaterThanOrEqualTo(0),
            reason: 'bar at $barTop with a $height callout',
          );
        }
      }
    });

    test('keeps the callout inside the plot whenever one can fit', () {
      for (final barTop in <double>[0, 37.5, 60, 120, 199]) {
        const height = 80.0;
        final top = clampedOverlayTop(
          barTop: barTop,
          height: height,
          gap: 6,
          plotHeight: 200,
        );
        expect(top + height, lessThanOrEqualTo(200.01), reason: '$barTop');
      }
    });

    test('a callout taller than the plot starts at the ceiling', () {
      expect(
        clampedOverlayTop(barTop: 120, height: 200, gap: 6, plotHeight: 200),
        0,
      );
      expect(
        clampedOverlayTop(barTop: 120, height: 260, gap: 6, plotHeight: 200),
        0,
      );
    });
  });
}
