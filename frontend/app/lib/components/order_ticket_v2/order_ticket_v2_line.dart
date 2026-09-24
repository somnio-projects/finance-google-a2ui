import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_stepper.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_weight_bar.dart';
import 'package:flutter/material.dart';

/// One leg of the draft, as the design draws it.
///
/// Measured: radius **12**, padding **10 × 12**, a 1 px hairline and a
/// **3 px** rail down the left edge. The ticker, `@ price` and the amount
/// share the first row; the stepper and the weight bar the second, 9 px
/// below. A leg that was just stepped takes the highlighted surface, border
/// and rail; its amount, shares and weight — and every leg's weight — take
/// the indigo when their string changed.
///
/// Every string here is the backend's. The bar's fill is the one raw member
/// this component reads, and it is a width, not a figure (N-4).
class OrderTicketV2LineTile extends StatelessWidget {
  /// Creates the tile.
  const OrderTicketV2LineTile({
    required this.line,
    required this.isStepped,
    required this.changed,
    required this.onLegsChanged,
    super.key,
  });

  /// The leg's corner radius, measured from the design.
  static const double radius = 12;

  /// The rail down the leg's left edge, measured from the design.
  static const double railWidth = 3;

  /// The leg.
  final OrderTicketV2Line line;

  /// Whether this leg's share count moved on the last render.
  final bool isStepped;

  /// Slot names whose display string changed on the last render.
  final Set<String> changed;

  /// Receives the `legs` value a stepper tap sends; null disables it.
  final ValueChanged<String>? onLegsChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    final amountChanged = changed.contains(LineSlots.notional(line.key));
    final weightChanged = changed.contains(LineSlots.weight(line.key));
    return Semantics(
      container: true,
      label: '${line.symbol}, ${line.name}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isStepped ? palette.changedSurface : palette.legSurface,
          border: Border.all(
            color: isStepped ? palette.changedBorder : palette.legBorder,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          // The rail stretches to the row's height, which a `Column` of
          // minimum size does not bound on its own.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: railWidth,
                  child: ColoredBox(
                    color: isStepped
                        ? palette.changedAccent
                        : palette.legAccent,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              line.symbol,
                              style: OrderTicketV2Text.symbol(palette.text),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '@ ${line.priceDisplay}',
                                style: OrderTicketV2Text.price(palette.subText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              line.notionalDisplay,
                              style: OrderTicketV2Text.amount(
                                amountChanged ? palette.changed : palette.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: <Widget>[
                            OrderTicketV2Stepper(
                              line: line,
                              isChanged: changed.contains(
                                LineSlots.quantity(line.key),
                              ),
                              onLegsChanged: onLegsChanged,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OrderTicketV2WeightBar(
                                fraction: line.weight,
                                display: line.weightDisplay,
                                isChanged: weightChanged,
                                ringColor: isStepped
                                    ? palette.changedSurface
                                    : palette.legSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
