import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter/material.dart';

/// The ticket's heading: what is being ordered, and which way.
class OrderTicketHeader extends StatelessWidget {
  /// Creates the header.
  const OrderTicketHeader({required this.data, super.key});

  /// The ticket to describe.
  final OrderTicketData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                data.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _SideChip(side: data.side),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${data.symbol} · ${data.name}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedLabel,
          ),
        ),
      ],
    );
  }
}

/// The `side` payload field, shown as the backend wrote it.
///
/// `side` is both a payload field and a declared option — that is the
/// contract's way of saying it is editable (ADR-K D-3). It is shown here as
/// well as offered as a control, because the design's header states which way
/// the order goes.
class _SideChip extends StatelessWidget {
  const _SideChip({required this.side});

  final String side;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: palette.barTotal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        side,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: palette.barTotal, fontWeight: FontWeight.w600),
      ),
    );
  }
}
