import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// The realised result, split short-term against long-term.
///
/// Three server-written values and nothing else: the caption is
/// `realized.label`, the total is `realized.amount.display`, and each pill
/// is one `by_term` half. **The split is not computed here** — it is the
/// whole point of the surface and the backend already carries it (N-2).
///
/// The total is drawn in [TaxLotPalette.primaryText] rather than the
/// design's green. The design colours it by sign; `realized` carries no
/// `direction` or `trend` the way each lot does, and the two ways to get
/// one back — reading the `+` off the display string, or taking the sign
/// through the geometry seam — are the parse N-1 forbids and a use ADR-L
/// D-14 reserves for canvas coordinates. Spec `frontend/0003` OD-4 asks the
/// backend for the field.
class TaxLotsTableFooter extends StatelessWidget {
  /// Creates the footer bar.
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
        child: Container(
          decoration: BoxDecoration(
            color: palette.footerSurface,
            border: Border.all(color: palette.border),
            borderRadius: TaxLotMetrics.footerBorderRadius,
          ),
          padding: TaxLotMetrics.footerPadding,
          // A `Wrap`, not a `Row`: at the design width the caption sits
          // left and the figures right, exactly as the artboard draws it,
          // and when the width is not there the figures drop to a second
          // line instead of overflowing. The card is laid out by whatever
          // column it lands in — there is no breakpoint to keep in step —
          // and a pill's text is a server string whose length this app
          // does not get to choose.
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
                style: TaxLotType.footerLabel(palette.labelText),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TaxLotMetrics.footerGap,
                runSpacing: TaxLotMetrics.footerGap,
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
      ),
    );
  }

  /// One half's pill.
  ///
  /// The design abbreviates to `$4,100 LT`; the contract's short name for a
  /// half is its `label`, so the pill reads `+$8,925.00 Long-term`. Coining
  /// `LT` in Dart would be client-authored copy that ignores the `locale`
  /// option — spec `frontend/0003` OD-5.
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
