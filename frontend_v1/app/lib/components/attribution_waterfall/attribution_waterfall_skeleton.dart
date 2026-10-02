import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/skeleton/skeleton_pulse.dart';
import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';

/// The `AttributionWaterfall` card while its payload is on the way — the UI
/// Kit's *Loading* state: a title bar, a figure bar opposite it, and seven
/// grey columns of uneven height, each with a stub where its delta will go.
///
/// **No text and no number of any kind.** A placeholder that looked like a
/// figure would be a figure the client made up (N-3), so the skeleton draws
/// only boxes — not even the `payoff()…` pill its sibling card carries.
///
/// It composes the 0015 primitives and declares no `AnimationController`, so
/// reduced motion is inherited rather than re-implemented (ADR-L, spec
/// frontend/0020 OD-7).
class AttributionWaterfallSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const AttributionWaterfallSkeleton({super.key});

  /// The seven columns' heights, as fractions of the plot, traced off the
  /// artboard. They are uneven on purpose: seven equal bars read as a bar
  /// chart that has finished loading.
  static const List<double> columnHeights = <double>[
    0.14,
    0.46,
    0.40,
    0.31,
    0.28,
    0.21,
    0.58,
  ];

  /// A column's painted width, measured.
  static const double columnWidth = 26;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = SkeletonTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AttributionWaterfallCard.radius),
      ),
      child: Padding(
        padding: AttributionWaterfallCard.padding,
        child: SkeletonPulse(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _Block(width: 168, height: 12, color: tokens.bar),
                  const Spacer(),
                  _Block(width: 84, height: 10, color: tokens.bar),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: WaterfallChart.plotHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final height in columnHeights)
                      Expanded(
                        child: _Column(height: height, tokens: tokens),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One grey column with the stub of its delta label above it.
class _Column extends StatelessWidget {
  const _Column({required this.height, required this.tokens});

  final double height;
  final SkeletonTokens tokens;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _Block(
        width: AttributionWaterfallSkeleton.columnWidth - 6,
        height: 7,
        color: tokens.pill,
      ),
      const SizedBox(height: 6),
      _Block(
        width: AttributionWaterfallSkeleton.columnWidth,
        height: WaterfallChart.plotHeight * height,
        color: tokens.bar,
      ),
    ],
  );
}

/// A rounded grey block.
class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
