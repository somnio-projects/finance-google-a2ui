import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_buttons.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_grid.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_notice.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_shift_row.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The design's `ORDER IMPACT · recomputed on edit` panel.
///
/// Measured: radius **14**, padding **13 × 15**, a 1 px hairline; the four
/// figures in a two-column grid 12 px apart vertically and 18 px across; the
/// `Portfolio weight` rows 12 px below, radius 9, padding 8 × 11; the notice
/// and the buttons after. After a step the whole panel takes the highlighted
/// surface and the caption reads `just recomputed`, as the design's `Lb`
/// artboard draws it.
///
/// Every string is the backend's. Which figures are marked is decided
/// upstream by comparing display strings (N-2); whether the draft is blocked
/// is the backend's `breach`, read, never a comparison here.
class OrderTicketV2Impact extends StatelessWidget {
  /// Creates the panel.
  const OrderTicketV2Impact({
    required this.data,
    required this.changed,
    this.rejection,
    super.key,
  });

  /// The panel's corner radius, measured from the design.
  static const double radius = 14;

  /// The panel's padding, measured from the design: `13px 15px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 15,
    vertical: 13,
  );

  /// The section caption — the app's chrome, like `OrderTicketImpact`'s.
  static const String caption = 'Order impact';

  /// What the caption's note says at rest, and after a step.
  static const String noteAtRest = 'recomputed on edit';

  /// See [noteAtRest].
  static const String noteAfterStep = 'just recomputed';

  /// The ticket.
  final OrderTicketV2Data data;

  /// Slot names whose display string changed on the last render.
  final Set<String> changed;

  /// A refused edit's message, shown as a notice beside any breach.
  final String? rejection;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    final recomputed = changed.isNotEmpty;
    return Semantics(
      container: true,
      label: recomputed ? '$caption, updated' : caption,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: recomputed ? palette.changedSurface : palette.panelSurface,
          border: Border.all(
            color: recomputed ? palette.changedBorder : palette.border,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Caption(note: recomputed ? noteAfterStep : noteAtRest),
              const SizedBox(height: 11),
              OrderTicketV2Grid(data: data, changed: changed),
              for (final shift in data.shifts) ...<Widget>[
                const SizedBox(height: 12),
                OrderTicketV2ShiftRow(
                  shift: shift,
                  isChanged: changed.contains(LineSlots.shift(shift.key)),
                ),
              ],
              if (data.message case final String message) ...<Widget>[
                const SizedBox(height: 12),
                OrderTicketV2Notice(message: message),
              ],
              if (rejection case final String message) ...<Widget>[
                const SizedBox(height: 12),
                OrderTicketV2Notice(message: message),
              ],
              const SizedBox(height: 13),
              const OrderTicketV2Buttons(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    return Row(
      children: <Widget>[
        Text(
          OrderTicketV2Impact.caption.toUpperCase(),
          style: OrderTicketV2Text.caption(palette.label),
        ),
        const SizedBox(width: 6),
        DecoratedBox(
          decoration: BoxDecoration(color: palette.dot, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 5),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            note,
            style: OrderTicketV2Text.figureLabel(palette.mutedText),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
