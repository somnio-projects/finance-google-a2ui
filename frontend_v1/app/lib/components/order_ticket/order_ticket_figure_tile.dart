import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/order_ticket/order_ticket_figure.dart';
import 'package:flutter/material.dart';

/// One caption-and-figure pair; a changed figure takes the accent.
class OrderTicketFigureTile extends StatelessWidget {
  /// Creates the tile.
  const OrderTicketFigureTile({
    required this.figure,
    required this.isChanged,
    super.key,
  });

  /// The figure to show.
  final OrderTicketFigure figure;

  /// Whether its display string changed in the last render.
  final bool isChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    return Semantics(
      label: figure.label,
      value: figure.display,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            figure.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.mutedLabel,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            figure.display,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isChanged ? palette.barTotal : palette.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
