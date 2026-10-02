// The golden calibration, asserted on rasters built by hand.
//
// `flutter_test_config.dart` carries the measurements GGU-106 produced; this
// carries the cases, so the numbers are a test rather than a comment. Synthetic
// buffers rather than PNGs on purpose: a rasteriser would make the assertions
// depend on the platform they were written on, which is the property this whole
// comparator exists to work around.
//
// The two rows that matter are the ones the single-axis metric could not tell
// apart — a trace amplitude over the whole frame, and a real amplitude over the
// same area.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'golden_difference.dart';

/// A 100-pixel RGBA buffer, every channel [value].
Uint8List _flat(int value) => Uint8List(400)..fillRange(0, 400, value);

/// [master] with the first [count] pixels moved by [delta] on every channel.
Uint8List _shifted(Uint8List master, {required int count, required int delta}) {
  final candidate = Uint8List.fromList(master);
  for (var index = 0; index < count * 4; index++) {
    candidate[index] = master[index] + delta;
  }
  return candidate;
}

void main() {
  group('GoldenDifference (spec frontend/0029, GGU-106)', () {
    test('an identical raster differs on neither axis', () {
      final master = _flat(120);
      final difference = GoldenDifference.betweenPixels(
        master,
        Uint8List.fromList(master),
      );
      expect(difference.differingFraction, 0);
      expect(difference.visiblyDifferentFraction, 0);
      expect(difference.maxChannelDelta, 0);
      expect(difference.isWithinTolerance, isTrue);
    });

    test('a trace change over the whole frame is invisible, not a failure', () {
      // The translucency case: 100 % of pixels differ, by 2/255. Measured on
      // the real payoff golden as 83.893 % at max Δ 2 — the number the old
      // single-axis comparator reported as a catastrophe.
      final master = _flat(120);
      final difference = GoldenDifference.betweenPixels(
        master,
        _shifted(master, count: 100, delta: GoldenDifference.amplitudeFloor),
      );
      expect(difference.differingFraction, 1);
      expect(difference.visiblyDifferentFraction, 0);
      expect(difference.maxChannelDelta, GoldenDifference.amplitudeFloor);
      expect(difference.isWithinTolerance, isTrue);
    });

    test('one unit above the floor over the whole frame fails', () {
      // The floor is inclusive and the smallest value the measurement supports,
      // so this is the boundary: 3/255 everywhere is a failure. A tolerance
      // padded past its measurement is how the old one came to cover a case it
      // had never been measured on.
      final master = _flat(120);
      final difference = GoldenDifference.betweenPixels(
        master,
        _shifted(
          master,
          count: 100,
          delta: GoldenDifference.amplitudeFloor + 1,
        ),
      );
      expect(difference.visiblyDifferentFraction, 1);
      expect(difference.isWithinTolerance, isFalse);
      expect(difference.describe(), contains('Largest channel delta: 3/255'));
    });

    test('a large change over a hairline is within tolerance', () {
      // Cross-platform anti-aliasing: one pixel in a hundred, flipped between
      // two colours. The amplitude floor deliberately does NOT suppress this —
      // the area threshold does, which is why both axes are kept.
      final master = _flat(40);
      final difference = GoldenDifference.betweenPixels(
        master,
        _shifted(master, count: 1, delta: 200),
      );
      expect(difference.visiblyDifferentFraction, 0.01);
      expect(difference.maxChannelDelta, 200);
      expect(difference.isWithinTolerance, isTrue);
    });

    test('a large change over more than the area threshold fails', () {
      final master = _flat(40);
      final difference = GoldenDifference.betweenPixels(
        master,
        _shifted(master, count: 2, delta: 200),
      );
      expect(difference.visiblyDifferentFraction, 0.02);
      expect(difference.isWithinTolerance, isFalse);
      expect(difference.describe(), contains('tolerance 1.5 %'));
    });

    test('the area threshold is inclusive at its stated value', () {
      // 1.5 % of 100 pixels is 1.5, so a hundred-pixel frame cannot land on the
      // boundary; this asserts the comparison itself rather than a rounding.
      expect(
        const GoldenDifference(
          differingFraction: 1,
          visiblyDifferentFraction:
              GoldenDifference.maxVisiblyDifferentFraction,
          maxChannelDelta: 9,
        ).isWithinTolerance,
        isTrue,
      );
    });

    test('a raster of a different size is never within tolerance', () {
      // A reflow is what a golden is for, and no per-pixel comparison is even
      // defined across two sizes — so this is a verdict, not a measurement.
      final resized = GoldenDifference.betweenPixels(_flat(10), Uint8List(800));
      expect(resized.isWithinTolerance, isFalse);
      expect(resized.maxChannelDelta, 255);
      // And an empty buffer, which would otherwise divide by zero and report a
      // NaN fraction that compares false against every threshold — the vacuity
      // failure `check_coverage.dart` shipped with, one layer down.
      expect(
        GoldenDifference.betweenPixels(
          Uint8List(0),
          Uint8List(0),
        ).isWithinTolerance,
        isFalse,
      );
    });
  });
}
