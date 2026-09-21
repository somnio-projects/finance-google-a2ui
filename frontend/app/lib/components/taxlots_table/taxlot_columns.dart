import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:flutter/widgets.dart';

/// Lays five flexible cells out after one fixed leading cell.
///
/// The design's rows are a CSS grid, `26px 1.05fr 0.95fr 0.95fr 1fr 1.02fr`
/// with an 8 px gap, and the column header line is the *same* grid so the
/// captions sit over their figures. One widget builds both, which is what
/// keeps them aligned: a header laid out separately from its rows drifts the
/// first time a weight changes.
///
/// [cells] must hold exactly five children. The check is an `assert` in
/// [build] rather than in the constructor: a miscounted grid is a
/// programming error, not a payload error, and a constructor assert would
/// have to give up `const`, because `List.length` is not available at
/// compile time and the analyzer rejects that pair.
class TaxLotColumns extends StatelessWidget {
  /// Creates a grid line.
  const TaxLotColumns({required this.leading, required this.cells, super.key});

  /// The fixed 26 px cell — the tick box, or a blank in the header.
  final Widget leading;

  /// The five flexible cells, in design order: acquired, cost basis,
  /// proceeds, gain/loss, term.
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    assert(
      cells.length == 5,
      'the design draws five flexible columns after the tick box',
    );
    return Row(
      children: <Widget>[
        SizedBox(width: TaxLotMetrics.checkColumnWidth, child: leading),
        for (final (index, cell) in cells.indexed) ...<Widget>[
          const SizedBox(width: TaxLotMetrics.columnGap),
          Expanded(flex: TaxLotMetrics.columnFlex[index], child: cell),
        ],
      ],
    );
  }
}
