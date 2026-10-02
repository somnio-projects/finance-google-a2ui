import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// The card's header: the title, the line under it, and the term key.
///
/// The kit's slot reads `NVDA · 4 lots` — a symbol and a count the contract
/// serves neither of. What it does serve is `title` and `subtitle`, both
/// required and both server-written, and N-9 does not let this client decide
/// one of them is not worth showing. So the header is two lines where the
/// artboard has one, with the legend still pinned right (spec `frontend/0027`
/// OD-4).
///
/// The two legend pills are `by_term`'s own halves, in arrival order (N-10),
/// so the key names exactly the terms the payload split its result by.
///
/// **[stacked] moves the key under the title**, and only the phone form asks
/// for it. The kit keeps both on one line at both widths, but its title is
/// `NVDA · 4 lots`; the contract's is a sentence, and a sentence beside two
/// pills at 328 px leaves the title two words wide. Dropping to a second
/// line is the honest degradation — the alternative is a header that reads
/// `Tax lo…` on a phone.
class TaxLotsTableHeader extends StatelessWidget {
  /// Creates the header line.
  const TaxLotsTableHeader({
    required this.data,
    required this.stacked,
    super.key,
  });

  /// The card's data.
  final TaxLotsTableData data;

  /// Whether the card is drawing its phone form.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    final legend = <Widget>[
      for (final (index, split) in data.splits.indexed) ...<Widget>[
        if (index > 0) const SizedBox(width: TaxLotMetrics.chipGap),
        _legendChip(palette, split),
      ],
    ];
    final caption = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TaxLotType.title(palette.primaryText),
        ),
        Text(
          data.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TaxLotType.subtitle(palette.mutedText),
        ),
      ],
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          caption,
          const SizedBox(height: TaxLotMetrics.chipGap),
          Row(children: legend),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: caption),
        const SizedBox(width: TaxLotMetrics.chipGap),
        ...legend,
      ],
    );
  }

  /// One key pill, from a `by_term` half's own label.
  Widget _legendChip(TaxLotPalette palette, TaxLotTermSplit split) {
    final term = split.term.colorsIn(palette);
    return TaxLotChip(
      label: split.label,
      background: term.chipBackground,
      padding: TaxLotMetrics.chipPadding,
      style: TaxLotType.chip(term.chipForeground),
    );
  }
}
