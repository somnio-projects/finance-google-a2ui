import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/skeleton/skeleton_caption.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';

/// The `HoldingsSummary` card while `get_holdings()` runs: the catalog page's
/// `Loading · skeleton` state — a shimmering ring with the card's own hole, a
/// title bar, a caption bar, four legend bars and the tool's name turning.
class HoldingsAllocationSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const HoldingsAllocationSkeleton({super.key});

  /// The caption under the bars — the tool the agent is waiting on.
  static const String caption = 'get_holdings()…';

  /// The ring, from `width:112px;height:112px`.
  static const double ringDiameter = 112;

  /// Its hole, from `width:68px;height:68px`.
  static const double holeDiameter = 68;

  /// The four legend bars' widths, as fractions of the card — the artboard's
  /// `skel` list, longest first the way a legend reads.
  static const List<double> legendWidths = <double>[0.88, 0.76, 0.82, 0.64];

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(HoldingsAllocationCard.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: SkeletonShimmer(
                  width: ringDiameter,
                  height: ringDiameter,
                  shape: BoxShape.circle,
                  child: Container(
                    width: holeDiameter,
                    height: holeDiameter,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SkeletonShimmer(
                height: 22,
                width: constraints.maxWidth * 0.7,
                radius: 6,
              ),
              const SizedBox(height: 10),
              SkeletonShimmer(
                height: 11,
                width: constraints.maxWidth * 0.45,
                radius: 5,
              ),
              const SizedBox(height: 16),
              for (final fraction in legendWidths)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: SkeletonShimmer(
                    height: 11,
                    width: constraints.maxWidth * fraction,
                    radius: 5,
                  ),
                ),
              const SizedBox(height: 4),
              const SkeletonCaption(text: caption, mono: true),
            ],
          ),
        ),
      ),
    );
  }
}
