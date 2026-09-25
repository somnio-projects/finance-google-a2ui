import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// The realised result, split short-term against long-term.
///
/// A rule and a line of text — the kit dropped the filled bar the earlier
/// artboard had. Three server-written values and nothing else: the caption is
/// `realized.label`, the total is `realized.amount.display`, and each pill is
/// one `by_term` half. **The split is not computed here** — it is the whole
/// point of the surface and the backend already carries it (N-2).
///
/// The caption is also what makes the kit's two footer states one widget:
/// *Realized gain if sold* and *Realized on selected sale* are the same
/// field with different content, chosen by the backend for the sale it was
/// asked about.
///
/// The total is drawn in [TaxLotPalette.primaryText] rather than the kit's
/// green. The kit colours it by sign; `realized` carries no `direction` or
/// `trend` the way each lot does, and the two ways to get one back — reading
/// the `+` off the display string, or taking the sign through the geometry
/// seam — are the parse N-1 forbids and a use ADR-L D-14 reserves for canvas
/// coordinates. Spec `frontend/0027` OQ-4 asks the backend for the field.
class TaxLotsTableFooter extends StatelessWidget {
  /// Creates the footer line.
  const TaxLotsTableFooter({
    required this.label,
    required this.totalDisplay,
    required this.splits,
    super.key,
  });

  /// The payload's `realized.label`.
  final String label;

  /// The payload's `realized.amount.display`.
  final String totalDisplay;

  /// The `by_term` halves, in arrival order (N-10).
  final List<TaxLotTermSplit> splits;

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    return Semantics(
      container: true,
      label: '$label $totalDisplay',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Divider(
              height: TaxLotMetrics.dividerThickness,
              thickness: TaxLotMetrics.dividerThickness,
              color: palette.divider,
            ),
            Padding(
              padding: TaxLotMetrics.footerPadding,
              // A `Wrap`, not a `Row`: at the kit's width the caption sits
              // left and the figures right, exactly as the artboard draws
              // it, and when the width is not there the figures drop to a
              // second line instead of overflowing. The card is laid out by
              // whatever column it lands in, and a pill's text is a server
              // string whose length this app does not get to choose.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TaxLotMetrics.footerGap,
                runSpacing: TaxLotMetrics.footerGap,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TaxLotType.footerLabel(palette.mutedText),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TaxLotMetrics.chipGap,
                    runSpacing: TaxLotMetrics.chipGap,
                    children: <Widget>[
                      Text(
                        totalDisplay,
                        style: TaxLotType.footerTotal(palette.primaryText),
                      ),
                      for (final split in splits) _splitChip(palette, split),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One half's pill.
  ///
  /// The kit abbreviates to `$4,100 LT`; the contract's short name for a half
  /// is its `label`, so the pill reads `+$26,679.60 Long-term`. Coining `LT`
  /// in Dart would be client-authored copy that ignores the `locale` option
  /// (`frontend/0003` OD-5, carried forward).
  Widget _splitChip(TaxLotPalette palette, TaxLotTermSplit split) {
    final term = split.term.colorsIn(palette);
    return TaxLotChip(
      label: '${split.realizedDisplay} ${split.label}',
      background: term.chipBackground,
      padding: TaxLotMetrics.footerChipPadding,
      style: TaxLotType.footerChip(term.chipForeground),
    );
  }
}
