import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The design's `Portfolio weight · Semis  6.2% → 8.3%` row.
///
/// Measured: radius 9, padding 8 × 11, on the panel's inset surface. The
/// `after` figure takes the indigo when its string changed.
class OrderTicketV2ShiftRow extends StatelessWidget {
  /// Creates the row.
  const OrderTicketV2ShiftRow({
    required this.shift,
    required this.isChanged,
    super.key,
  });

  /// The group's shift.
  final OrderTicketV2Shift shift;

  /// Whether its `after` string changed on the last render.
  final bool isChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    return Semantics(
      label: shift.label,
      value: '${shift.beforeDisplay} to ${shift.afterDisplay}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.shiftSurface,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  shift.label,
                  style: OrderTicketV2Text.shiftLabel(palette.subText),
                ),
              ),
              Text(
                shift.beforeDisplay,
                style: OrderTicketV2Text.shiftBefore(palette.mutedText),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '→',
                  style: OrderTicketV2Text.shiftBefore(palette.mutedText),
                ),
              ),
              Text(
                shift.afterDisplay,
                style: OrderTicketV2Text.shiftAfter(
                  isChanged ? palette.changed : palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
