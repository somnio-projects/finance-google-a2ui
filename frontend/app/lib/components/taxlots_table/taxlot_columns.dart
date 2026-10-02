import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:flutter/widgets.dart';

/// Lays the table's six flexible cells out after the rail and the tick box.
///
/// The kit's rows are a grid and the caption line is the *same* grid, so the
/// captions sit over their figures. One widget builds both, which is what
/// keeps them aligned: a caption line laid out separately from its rows
/// drifts the first time a weight changes.
///
/// [cells] must hold exactly six children. The check is an `assert` in
/// [build] rather than in the constructor: a miscounted grid is a programming
/// error, not a payload error, and a constructor assert would have to give up
/// `const`, because `List.length` is not available at compile time and the
/// analyzer rejects that pair.
class TaxLotColumns extends StatelessWidget {
  /// Creates a grid line.
  const TaxLotColumns({required this.leading, required this.cells, super.key});

  /// What sits where the tick box goes — the box itself, or a blank of the
  /// same width in the caption line.
  final Widget leading;

  /// The six flexible cells, in design order: acquired, shares, cost basis,
  /// market value, gain/loss, holding period.
  final List<Widget> cells;

  /// The rail, the box and the two gaps around them, which the caption line
  /// must skip to sit over the figures.
  static const double leadingWidth =
      TaxLotMetrics.railWidth +
      TaxLotMetrics.railGap +
      TaxLotMetrics.checkBoxSize;

  @override
  Widget build(BuildContext context) {
    assert(
      cells.length == TaxLotMetrics.columnFlex.length,
      'the kit draws six flexible columns after the tick box',
    );
    return Row(
      children: <Widget>[
        SizedBox(width: leadingWidth, child: leading),
        for (final (index, cell) in cells.indexed) ...<Widget>[
          // The first gap is the one after the tick box, which the kit sets
          // a pixel wider than the gap between two columns.
          SizedBox(
            width: index == 0 ? TaxLotMetrics.railGap : TaxLotMetrics.columnGap,
          ),
          Expanded(flex: TaxLotMetrics.columnFlex[index], child: cell),
        ],
      ],
    );
  }
}
