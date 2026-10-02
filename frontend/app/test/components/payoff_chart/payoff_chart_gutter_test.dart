import 'package:finance_app/charts/payoff_marks_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// GGU-146 — the value labels sit in the gutter, outside the plot.
///
/// **This is the check the golden could not be.** The rung labels were drawn
/// one gutter too far right, inside the wash; `--update-goldens` froze it
/// without complaint and a browser found it. The crop that keeps the
/// goldens' cross-platform noise inside tolerance is deliberately text-free,
/// so it cannot see a label at all — the position has to be asserted here.
///
/// It asserts the **offset function** rather than the raster. A pixel census
/// of the rendered chart would be the stronger check and was written first;
/// `toImage` inside a widget test hangs rather than failing, and a check that
/// cannot be run is worth less than a narrow one that can. What this does
/// catch is the exact defect: `gutter - rungGap - width` is *positive*
/// whenever the gutter exceeds the label, which is every real payload.
void main() {
  group('rungLabelLeft', () {
    test('puts every label outside the plot, whatever it says', () {
      for (final width in <double>[0, 1, 12.5, 44, 180]) {
        expect(
          rungLabelLeft(width),
          lessThanOrEqualTo(-rungGap),
          reason: 'a $width pt label must start left of the plot',
        );
      }
    });

    test('keeps the measured clearance between the label and the plot', () {
      expect(rungLabelLeft(44) + 44, -rungGap);
    });
  });
}
