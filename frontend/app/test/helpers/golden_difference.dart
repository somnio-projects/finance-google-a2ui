import 'dart:typed_data';
import 'dart:ui' as ui;

/// How far two rasters differ, on the **two** axes a golden needs.
///
/// Flutter's comparator reports one number — the fraction of pixels that
/// differ *at all* — and for translucent paint that number is meaningless. A
/// wash covers every pixel in its region, so nudging its alpha by a trace
/// amount moves ~all of them by 1–2/255: measured at **83.9 %** of pixels
/// changed for a **2/255** change nobody can see (GGU-106, spec
/// frontend/0029 §4). The same metric reports **2.1 %** for an opaque bar
/// drawn in flatly the wrong colour. A metric that ranks an invisible change
/// forty times above a visible one is not a threshold problem.
///
/// So *area* and *amplitude* are measured separately, and the verdict uses
/// both: a pixel is counted only once it differs by more than
/// [amplitudeFloor], and that count is compared with
/// [maxVisiblyDifferentFraction]. The two gates catch different noise, which
/// is the point — translucency is many pixels at a trace amplitude,
/// cross-platform anti-aliasing is few pixels at a large one.
class GoldenDifference {
  /// Creates a measurement. Normally read from
  /// [GoldenDifference.betweenPixels].
  const GoldenDifference({
    required this.differingFraction,
    required this.visiblyDifferentFraction,
    required this.maxChannelDelta,
  });

  /// Measures two same-length RGBA buffers.
  ///
  /// Raw pixels rather than PNGs, so the calibration is unit-testable without
  /// a rasteriser — `golden_difference_test.dart` builds its cases by hand,
  /// which is the only way these thresholds get asserted rather than asserted
  /// *about*.
  factory GoldenDifference.betweenPixels(
    Uint8List master,
    Uint8List candidate,
  ) {
    if (master.length != candidate.length || master.isEmpty) {
      return sizeMismatch;
    }
    final pixels = master.length ~/ 4;
    var differing = 0;
    var visiblyDiffering = 0;
    var maxDelta = 0;
    for (var pixel = 0; pixel < pixels; pixel++) {
      var delta = 0;
      for (var channel = 0; channel < 4; channel++) {
        final index = pixel * 4 + channel;
        final channelDelta = (master[index] - candidate[index]).abs();
        if (channelDelta > delta) delta = channelDelta;
      }
      if (delta > 0) differing++;
      if (delta > amplitudeFloor) visiblyDiffering++;
      if (delta > maxDelta) maxDelta = delta;
    }
    return GoldenDifference(
      differingFraction: differing / pixels,
      visiblyDifferentFraction: visiblyDiffering / pixels,
      maxChannelDelta: maxDelta,
    );
  }

  /// A raster whose dimensions do not match its golden.
  ///
  /// Never within tolerance: a reflow is the thing goldens exist to catch,
  /// and no per-pixel comparison is even defined across two sizes.
  static const GoldenDifference sizeMismatch = GoldenDifference(
    differingFraction: 1,
    visiblyDifferentFraction: 1,
    maxChannelDelta: 255,
  );

  /// Per channel, inclusive: a pixel differing by this much counts as
  /// *identical* for the purposes of the verdict.
  ///
  /// **2, the measured amplitude of the invisible change**, chosen as the
  /// smallest value that admits it rather than a comfortable margin above it.
  /// A re-render landing at 3/255 fails, deliberately: padding a tolerance
  /// past its measurement is how the single-axis threshold came to cover a
  /// case it had never been measured on.
  static const int amplitudeFloor = 2;

  /// The share of *visibly* different pixels a golden may carry.
  ///
  /// **Unchanged at 1.5 %** — the measured 0.69 % cross-platform noise floor
  /// and the 4.97 % smallest real defect that chose it are still the two ends,
  /// and this change touches neither. Only the population being measured
  /// changed. It goes **down** as the noise is understood better, never up to
  /// absorb a failure.
  static const double maxVisiblyDifferentFraction = 0.015;

  /// Pixels differing at all — what Flutter's comparator reports. Kept for the
  /// failure message, because the gap between the two is the diagnosis.
  final double differingFraction;

  /// Pixels differing by more than [amplitudeFloor]: the verdict's axis.
  final double visiblyDifferentFraction;

  /// The largest single-channel difference anywhere in the raster.
  final int maxChannelDelta;

  /// Whether the candidate may stand in for the golden.
  bool get isWithinTolerance =>
      visiblyDifferentFraction <= maxVisiblyDifferentFraction;

  /// Both axes, in the words the calibration uses, for a failure message.
  String describe() =>
      'visibly different: '
      '${(visiblyDifferentFraction * 100).toStringAsFixed(3)} % of pixels '
      'differ by more than $amplitudeFloor/255 '
      '(tolerance '
      '${(maxVisiblyDifferentFraction * 100).toStringAsFixed(1)} %). '
      'Differing at all: '
      '${(differingFraction * 100).toStringAsFixed(3)} %. '
      'Largest channel delta: $maxChannelDelta/255.';

  /// Decodes two PNGs and measures them.
  static Future<GoldenDifference> betweenPngs(
    Uint8List master,
    Uint8List candidate,
  ) async => GoldenDifference.betweenPixels(
    await _rgba(master),
    await _rgba(candidate),
  );

  static Future<Uint8List> _rgba(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    frame.image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  }
}
