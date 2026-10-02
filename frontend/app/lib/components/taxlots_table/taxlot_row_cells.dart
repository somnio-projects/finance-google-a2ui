import 'package:finance_app/components/taxlots_table/taxlot_figure.dart';
import 'package:flutter/material.dart';

/// One text cell of a table row, or of the phone card's grid.
///
/// Always one line: the kit's rows are a fixed height and a cell that wrapped
/// would push its neighbours out of alignment. A value too wide for its
/// column is scaled down by [TaxLotFigure], never ellipsised (GGU-148).
/// [text] is always a string the backend wrote — nothing here formats,
/// joins or trims a figure (N-1).
class TaxLotCell extends StatelessWidget {
  /// Creates a cell.
  const TaxLotCell(this.text, {required this.style, this.align, super.key});

  /// The value, verbatim.
  final String text;

  /// The measured type for this column, already tinted with the colour its
  /// role takes — `TaxLotType`'s roles are functions of their colour.
  final TextStyle style;

  /// The design's alignment for this column.
  final TextAlign? align;

  @override
  Widget build(BuildContext context) =>
      TaxLotFigure(text, style: style, align: align);
}
