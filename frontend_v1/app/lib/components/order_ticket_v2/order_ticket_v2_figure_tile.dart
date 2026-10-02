import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// One label-over-figure cell of the impact panel.
///
/// Measured: a 10 px label 2 px above a 16 px figure. A changed figure takes
/// the indigo; the cash figure takes the negative colour when the backend
/// declared the draft blocked — the colour follows a **declared** flag, never
/// the sign of a string this client parsed (N-1, spec backend/0031 OD-4).
class OrderTicketV2FigureTile extends StatelessWidget {
  /// Creates the tile.
  const OrderTicketV2FigureTile({
    required this.figure,
    required this.isChanged,
    this.isNegative = false,
    super.key,
  });

  /// The figure shown.
  final OrderTicketV2Figure figure;

  /// Whether its display string changed on the last render.
  final bool isChanged;

  /// Whether the backend declared the draft over this figure's bound.
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    final color = isNegative
        ? palette.negative
        : isChanged
        ? palette.changed
        : palette.text;
    return Semantics(
      label: figure.label,
      value: figure.display,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            figure.label,
            style: OrderTicketV2Text.figureLabel(palette.mutedText),
          ),
          const SizedBox(height: 2),
          Text(figure.display, style: OrderTicketV2Text.figure(color)),
        ],
      ),
    );
  }
}
