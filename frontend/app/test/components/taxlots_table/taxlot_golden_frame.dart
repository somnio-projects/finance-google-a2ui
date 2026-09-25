/// The frame every tax-lot golden is shot through.
///
/// **A golden here shows chrome and never text.** The first attempt shot the
/// whole card and five of six failed on the Linux runner at 4.06–5.98 %
/// against a 1.5 % tolerance, light and dark differing by the *identical*
/// pixel count — the signature of glyph rasterisation rather than of anything
/// this code draws (ADR-L D-15, spec `frontend/0027` OD-10). Widening the
/// tolerance would be threshold-fitting; framing the claim is the fix.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The `RepaintBoundary` every golden in this suite is captured from.
const Key goldenSubject = Key('golden-subject');

/// [child] laid out at [width], framed to its left [crop] pixels.
///
/// `ClipRect` is what makes this a crop rather than a resize: the tree inside
/// is the real one at its real width, so the rails, the tint and the boxes
/// fall exactly where the card puts them. Callers compute [crop] from the
/// layout's own constants, so a grid change moves the frame with it instead
/// of letting a caption drift into shot.
Widget croppedFrame({
  required double width,
  required double crop,
  required Widget child,
}) => RepaintBoundary(
  key: goldenSubject,
  child: ClipRect(
    child: Align(
      alignment: Alignment.topLeft,
      widthFactor: crop / width,
      // `heightFactor: 1` hugs the child instead of filling the surface:
      // empty pixels are a diff denominator, and a frame that is mostly
      // blank dilutes the very change it is watching.
      heightFactor: 1,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

/// Pumps [subject] in the real theme and compares it with `goldens/[name]`.
Future<void> shootGolden(
  WidgetTester tester,
  Widget subject,
  String name, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpApp(
    Center(child: subject),
    brightness: brightness,
    surfaceSize: const Size(900, 900),
    // A shimmer repeats for ever, so a skeleton golden never settles without
    // this; it is also the state the card must be correct in.
    reducedMotion: true,
  );
  await expectLater(
    find.byKey(goldenSubject),
    matchesGoldenFile('goldens/$name.png'),
  );
}
