import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden_difference.dart';

/// Test-wide configuration; `flutter test` runs this around every suite.
///
/// It installs a tolerant golden comparator. Flutter's default demands a
/// byte-identical PNG, and a raster is **not** portable: the same widget
/// anti-aliases a rounded corner and a dashed connector differently on macOS
/// and on the Linux runner `frontend-ci` uses. A byte-exact golden generated on
/// a laptop is therefore a check that fails on CI for a reason that is not a
/// defect — which is worse than no check, because the fix everybody reaches for
/// is to stop running it.
///
/// **The comparator measures two things, because one was not enough**
/// (GGU-106). The tolerance was calibrated on **opaque bars**, and the payoff
/// chart shades half-planes with a translucent wash. A wash covers every pixel
/// in its region, so "the fraction of pixels that differ at all" saturates on
/// any adjustment to it — measured on this suite, under the pinned SDK:
///
/// | change | paint | differ | maxΔ | > 2/255 |
/// |---|---|---|---|---|
/// | re-render, no source change (×14) | both | 0.000 % | 0 | 0.000 % |
/// | wash .070 → .078, **invisible** | wash | **83.893 %** | **2** | 0.000 % |
/// | wash .070 → .100, other artboard | wash | 85.540 % | 8 | 83.020 % |
/// | wash .070 → .200 | wash | 85.627 % | 33 | 85.496 % |
/// | gain bar, other artboard's colour | opaque | 2.107 % | 94 | 2.093 % |
/// | gain bar +2/255, **invisible** | opaque | 2.029 % | 2 | **0.000 %** |
///
/// Read the `differ` column down that table and it ranks an invisible change
/// (83.9 %) forty times above a bar drawn in flatly the wrong colour (2.1 %).
/// That is not a threshold needing to be raised; it is the wrong question. The
/// last column asks the right one — *how many pixels changed by an amount a
/// person could see* — and separates the invisible cases (0.000 %) from the
/// real ones (2.1 %–85.5 %) with no overlap.
///
/// **It costs the opaque case almost nothing**, which is what makes this a
/// measurement fix rather than a loosened threshold: the wrong-colour bar
/// reads 2.107 % → 2.093 %, because a real recolour moves pixels by tens of
/// units and the amplitude floor drops only the 0.014 pp of anti-aliased edge.
/// And it is **provably** a relaxation and never a tightening — the pixels
/// counted are a subset of those counted before — so no golden that is green
/// today can turn red, which matters while other branches regenerate goldens.
///
/// Two earlier measurements still hold, and still choose the 1.5 %:
///
/// | change | pixels differing |
/// |---|---|
/// | macOS golden vs the Linux runner — **the noise floor** | **0.69 %** |
/// | the value scale's domain wrong | 6.9–7.3 % |
/// | one bar drawn in the wrong mark | 5.0 % |
/// | a bar's corner radius 4 px → 3 px | 0.08–0.11 % |
///
/// The last row is the honest limit: a sub-pixel radius change is **below**
/// what a cross-platform raster can resolve, so it is asserted as a constant
/// (`WaterfallPainter.barRadius`) rather than left to a golden. The exact
/// geometry is likewise proved arithmetically in `finance_charts` — that is
/// what makes a tolerance here safe.
///
/// Text in a golden renders in Flutter's test font, which is a block per
/// glyph — these prove bars, connectors, colours and layout, not typography.
/// The goldens deliberately capture the **chart**, not the card, because glyph
/// edges are where nearly all the cross-platform noise lives, and the
/// amplitude floor does **not** suppress it: an edge pixel flips between two
/// colours,
/// which is a large delta on few pixels. Spec frontend/0029 OD-8 records why
/// GGU-59's hairline crop therefore stays.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    final base = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = _TolerantComparator(Uri.parse('${base}x'));
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      goldenBytes,
    );
    if (result.passed) {
      result.dispose();
      return true;
    }
    final difference = await GoldenDifference.betweenPngs(
      goldenBytes,
      imageBytes,
    );
    if (difference.isWithinTolerance) {
      result.dispose();
      return true;
    }
    // `generateFailureOutput` writes the failure PNGs and names the file; both
    // measurements are appended because the gap between them is the diagnosis —
    // many pixels at a trace amplitude is a wash, few at a large one is a glyph
    // edge, many at a large one is the defect.
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw TestFailure('$error\n${difference.describe()}');
  }
}
