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
/// The tolerance is deliberately tight. It absorbs anti-aliasing; it does not
/// absorb a bar in the wrong place, a colour from the wrong palette or a
/// missing label, all of which move far more than
/// [_TolerantComparator.maxDifferentPixelFraction] of the image. The geometry
/// itself is proved exactly, and separately, in `finance_charts`.
///
/// Note that text in a golden renders in Flutter's test font, which is a
/// block per glyph — these prove bars, connectors, colours and layout, not
/// typography.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    final base = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = _TolerantComparator(Uri.parse('${base}x'));
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// One pixel in two hundred may differ. Measured against the three
  /// goldens in this suite, cross-platform anti-aliasing moves far less.
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
