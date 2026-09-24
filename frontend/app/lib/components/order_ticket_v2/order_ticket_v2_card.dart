import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_header.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_impact.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_line.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// Renders `order.ticket.v2` as the catalog page's card.
///
/// Measured off `Catalog_OrderTicket.dc.html` at 1024: radius **16**, padding
/// **16 × 18**, a 1 px hairline, legs 8 px apart, the impact panel 12 px
/// below them. One tree serves both artboards — only the palette differs.
///
/// **Interactivity is the host's.** [onLegsChanged] receives the whole `legs`
/// value a stepper tap sends — a string the backend wrote — and a host that
/// can re-request the view supplies it; one that cannot leaves it null and
/// the steppers render disabled (spec frontend/0006 AC-10, reused). Nothing
/// here computes: [changed] is a set of slot names decided upstream by
/// comparing display strings.
class OrderTicketV2Card extends StatelessWidget {
  /// Creates the card.
  const OrderTicketV2Card({
    required this.data,
    this.onLegsChanged,
    this.isBusy = false,
    this.rejection,
    this.changed = const <String>{},
    super.key,
  });

  /// The card's corner radius, measured from the design.
  static const double radius = 16;

  /// The card's padding, measured from the design: `16px 18px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  /// What to render.
  final OrderTicketV2Data data;

  /// Called with the `legs` option value to send; null makes the ticket
  /// read-only.
  final ValueChanged<String>? onLegsChanged;

  /// Whether a re-request is in flight: the steppers are held while it is,
  /// and the previous figures stay on screen.
  final bool isBusy;

  /// The backend's own `detail` for a refused edit, or a transport message.
  final String? rejection;

  /// Slot names whose display string changed on the last render.
  final Set<String> changed;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    final stepped = steppedLegs(changed, data);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            OrderTicketV2Header(data: data, stepped: stepped),
            const SizedBox(height: 12),
            for (final (index, line) in data.lines.indexed) ...<Widget>[
              if (index > 0) const SizedBox(height: 8),
              OrderTicketV2LineTile(
                line: line,
                isStepped: stepped.contains(line.key),
                changed: changed,
                onLegsChanged: isBusy ? null : onLegsChanged,
              ),
            ],
            const SizedBox(height: 12),
            OrderTicketV2Impact(
              data: data,
              changed: changed,
              rejection: rejection,
            ),
            const SizedBox(height: 12),
            // N-9: the disclosure is a compliance statement and renders
            // verbatim, in every state including the blocked one.
            Text(
              data.disclosure,
              style: OrderTicketV2Text.figureLabel(palette.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
