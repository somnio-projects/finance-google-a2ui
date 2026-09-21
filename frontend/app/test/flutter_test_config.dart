import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-wide configuration; `flutter test` runs this around every suite.
///
/// It installs a golden comparator with a small tolerance. Flutter's default
/// demands a byte-identical PNG, and a raster is **not** portable: the same
/// widget anti-aliases a rounded corner and a dashed connector differently on
/// macOS and on the Linux runner `frontend-ci` uses. A byte-exact golden
/// generated on a laptop is therefore a check that fails on CI for a reason
/// that is not a defect — which is worse than no check, because the fix
/// everybody reaches for is to stop running it.
///
/// **The threshold was measured, not guessed, and the margin is stated.**
/// Against the chart goldens in this suite:
///
/// | change | pixels differing |
/// |---|---|
/// | macOS golden vs the Linux runner, same tree (card goldens) | 0.54–0.70 % |
/// | the value scale's domain wrong | 6.9–7.3 % |
/// | one bar drawn in the wrong mark | 5.0 % |
/// | a bar's corner radius 4 px → 3 px | 0.08–0.11 % |
///
/// So a defect worth catching moves ten to a hundred times the tolerance.
/// The last row is the honest limit: a sub-pixel radius change is **below**
/// what a cross-platform raster can resolve, so it is asserted as a constant
/// (`WaterfallPainter.barRadius`) rather than left to a golden. The exact
/// geometry is likewise proved arithmetically in `finance_charts` — that is
/// what makes a tolerance here safe rather than a loosened threshold.
///
/// Note that text in a golden renders in Flutter's test font, which is a
/// block per glyph — these prove bars, connectors, colours and layout, not
/// typography. The goldens deliberately capture the **chart**, not the card,
/// because glyph edges are where nearly all the cross-platform noise lives.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    final base = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = _TolerantComparator(Uri.parse('${base}x'));
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// One pixel in two hundred may differ — see the table above for why that
  /// sits an order of magnitude below any defect worth catching.
  static const double maxDifferentPixelFraction = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= maxDifferentPixelFraction) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw TestFailure(error);
  }
}
