import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_surface.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';

/// The `TaxLotTable` card while its payload is on the way — the kit's
/// `Loading` artboard: a title bar, two pill bars, a caption bar, four row
/// bars, the card's one rule, and a footer bar.
///
/// It draws the card's **own** shape rather than the Assistant's generic
/// surface, because the kit draws one (ADR-L §3b, spec `frontend/0015`
/// OD-3), and it occupies the layout the table will occupy so nothing
/// reflows when the payload lands.
///
/// **No `AnimationController` here.** Every bar is a `SkeletonShimmer`, which
/// reads `MediaQuery.disableAnimations` itself — an animation nobody can turn
/// off is an accessibility defect, and composing the primitives is how that
/// is inherited rather than re-implemented (spec `frontend/0020` OD-7).
class TaxLotsTableSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const TaxLotsTableSkeleton({super.key});

  /// The title bar's width, as a fraction of the card.
  static const double titleFraction = 0.38;

  /// A legend pill bar's width.
  static const double pillWidth = 62;

  /// The bar that stands in for the caption line.
  static const double captionHeight = 10;

  /// How many row bars the artboard draws.
  static const int rowCount = 4;

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    return TaxLotsTableSurface(
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                SkeletonShimmer(
                  height: 18,
                  width: constraints.maxWidth * titleFraction,
                ),
                const Spacer(),
                const SkeletonShimmer(height: 17, width: pillWidth, radius: 8),
                const SizedBox(width: TaxLotMetrics.chipGap),
                const SkeletonShimmer(height: 17, width: pillWidth, radius: 8),
              ],
            ),
            const SizedBox(height: TaxLotMetrics.headerGap),
            const SkeletonShimmer(height: captionHeight, radius: 4),
            const SizedBox(height: TaxLotMetrics.captionGap),
            for (var index = 0; index < rowCount; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: TaxLotMetrics.rowGap),
              const SkeletonShimmer(height: TaxLotMetrics.rowHeight, radius: 6),
            ],
            const SizedBox(height: TaxLotMetrics.dividerGap),
            Divider(
              height: TaxLotMetrics.dividerThickness,
              thickness: TaxLotMetrics.dividerThickness,
              color: palette.divider,
            ),
            const Padding(
              padding: TaxLotMetrics.footerPadding,
              child: SkeletonShimmer(height: 22, radius: 6),
            ),
          ],
        ),
      ),
    );
  }
}
