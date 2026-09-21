import 'package:equatable/equatable.dart';

/// Divides a pixel width into equal bands, one per categorical slot.
///
/// d3's `scaleBand`, with the one addition the reference design needs: a bar
/// stops widening once it reaches [maxBarWidth]. Both constants below were
/// **measured** from the designer's two artboards rather than guessed — see
/// [defaultBarRatio].
class BandScale extends Equatable {
  /// Creates a band scale over [count] slots across [width] pixels.
  const BandScale({
    required this.count,
    required this.width,
    this.barRatio = defaultBarRatio,
    this.maxBarWidth = defaultMaxBarWidth,
  });

  /// The fraction of a band a bar occupies, leaving the rest as the gutter.
  ///
  /// The catalog page draws the same seven-band waterfall twice: at a plot
  /// width of 533.37 px the bars are 44.0 px on a 76.20 px band, and at
  /// 244.70 px they are 21.7 px on a 34.96 px band. The second gives
  /// 21.7 / 34.96 = 0.62; the first would give 47.2 px, which is capped by
  /// [defaultMaxBarWidth]. Two observations do not uniquely determine the
  /// rule — a constant gutter also fits them — and `specs/frontend/0002`
  /// records that, and why ratio-plus-cap was chosen.
  static const double defaultBarRatio = 0.62;

  /// The widest a bar gets, however much room the band has.
  static const double defaultMaxBarWidth = 44;

  /// How many bands. A waterfall has one per step: start, each bucket, end.
  final int count;

  /// The full plot width in pixels.
  final double width;

  /// See [defaultBarRatio].
  final double barRatio;

  /// See [defaultMaxBarWidth].
  final double maxBarWidth;

  /// The width of one band, gutter included.
  double get bandWidth => count <= 0 ? 0 : width / count;

  /// The painted width of a bar.
  double get barWidth {
    final proportional = bandWidth * barRatio;
    return proportional < maxBarWidth ? proportional : maxBarWidth;
  }

  /// The horizontal centre of band [index], which is also where its axis
  /// label and its connector are anchored.
  double center(int index) => bandWidth * (index + 0.5);

  /// The left edge of the bar in band [index].
  double barLeft(int index) => center(index) - barWidth / 2;

  /// The right edge of the bar in band [index].
  double barRight(int index) => center(index) + barWidth / 2;

  /// The band [x] falls in, or `null` when it is outside the plot.
  ///
  /// Hit testing is by **band**, not by bar: a tap in a bar's gutter still
  /// means the reader aimed at that step, and requiring them to hit a 21 px
  /// target would fail the 48 px minimum in
  /// `.claude/rules/flutter/ui-theming.md`.
  int? bandAt(double x) {
    if (count <= 0 || x < 0 || x >= width) return null;
    final index = (x / bandWidth).floor();
    return index < count ? index : null;
  }

  @override
  List<Object?> get props => <Object?>[count, width, barRatio, maxBarWidth];
}
