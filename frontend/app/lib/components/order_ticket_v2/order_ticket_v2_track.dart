import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_weight_bar.dart';
import 'package:flutter/material.dart';

/// The weight bar's rail: a rounded 4 px bar, drawn twice — once for the
/// groove and once, clipped to the fill's width, for the value.
///
/// Its own file because the bar crossed the 150-line budget when it learned
/// to accept a drag, and this is the seam that was already there: the shape
/// the bar is drawn from, apart from what the bar means.
class OrderTicketV2Track extends StatelessWidget {
  /// Creates a rail in [color].
  const OrderTicketV2Track({required this.color, super.key});

  /// The rail's colour — the groove's or the fill's.
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(
        OrderTicketV2WeightBar.trackHeight / 2,
      ),
    ),
    child: const SizedBox(
      height: OrderTicketV2WeightBar.trackHeight,
      width: double.infinity,
    ),
  );
}
