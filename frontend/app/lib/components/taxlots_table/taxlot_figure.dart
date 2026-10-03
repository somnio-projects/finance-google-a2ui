import 'package:flutter/material.dart';

/// One line of server-written text that is **never cut**.
///
/// A figure is a `*.display` string, and an ellipsis on `+$16,336.50` prints
/// a number the payload never sent — while the footer shows it whole, so the
/// row contradicts it (GGU-148). When the column is too narrow the line is
/// scaled down, not clipped; at the kit's widths nothing scales. Nothing here
/// formats, joins or trims the string (N-1).
class TaxLotFigure extends StatelessWidget {
  /// Draws [text] in [style], aligned like its column.
  const TaxLotFigure(this.text, {required this.style, this.align, super.key});

  /// The value, verbatim.
  final String text;

  /// The measured type for this column, already tinted.
  final TextStyle style;

  /// The design's alignment for this column.
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: switch (align) {
      TextAlign.right || TextAlign.end => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    },
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      textAlign: align,
      style: style,
    ),
  );
}
