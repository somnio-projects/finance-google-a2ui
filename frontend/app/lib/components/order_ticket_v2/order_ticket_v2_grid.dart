import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_figure_tile.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:flutter/material.dart';

/// The panel's four figures in the design's two-column grid: 12 px apart
/// vertically, 18 px across.
class OrderTicketV2Grid extends StatelessWidget {
  /// Creates the grid.
  const OrderTicketV2Grid({
    required this.data,
    required this.changed,
    super.key,
  });

  /// The ticket.
  final OrderTicketV2Data data;

  /// Slot names whose display string changed on the last render.
  final Set<String> changed;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (final figure in data.figures)
        OrderTicketV2FigureTile(
          figure: figure,
          isChanged: changed.contains(figure.name),
          isNegative: figure.name == 'cash' && data.isBlocked,
        ),
    ];
    return Column(
      children: <Widget>[
        for (var row = 0; row < tiles.length; row += 2)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: tiles[row]),
                const SizedBox(width: 18),
                Expanded(
                  child: row + 1 < tiles.length
                      ? tiles[row + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
