import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_toggle.dart';
import 'package:flutter/material.dart';

/// The card's top row: the header, and the grouping toggle beside it.
///
/// Its own file because the toggle made the card exceed the 150-line budget,
/// and because it carries the one rule worth stating on its own: **the
/// toggle is drawn only where a tap can be honoured.** A host that cannot
/// re-request gives the card no `onGroupChanged`, and a control that looks
/// live and does nothing is worse than no control — the same reason
/// `order_ticket_v2` renders its inputs read-only outside the Assistant
/// (spec frontend/0026).
class HoldingsAllocationHeaderRow extends StatelessWidget {
  /// Creates the row.
  const HoldingsAllocationHeaderRow({
    required this.data,
    this.onGroupChanged,
    this.isBusy = false,
    super.key,
  });

  /// The gap between the header and the toggle.
  static const double gap = 12;

  /// Below this width the toggle drops onto its own line.
  ///
  /// **Not measured, and that matters.** The design draws this card at 1024,
  /// where the header and a three-segment toggle share a row comfortably;
  /// there is no narrow artboard for it. At the Assistant's own width the two
  /// do not fit, and the first version of this row proved it by ellipsising
  /// the total — `$482,915.20` vanished from two Assistant tests, which is
  /// the GGU-144 lesson arriving one component later: a layout checked only
  /// at the artboard's width has been checked at the one width that cannot
  /// fail. The number is the total at its 30 pt size plus the widest toggle,
  /// rounded up; `specs/frontend/0033` OD-2 records that design should
  /// replace it with a drawn answer.
  static const double sideBySideFrom = 480;

  /// The model.
  final AllocationData data;

  /// Called with a grouping's `value`, or null where none can be honoured.
  final ValueChanged<String>? onGroupChanged;

  /// True while a re-render is in flight.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final onChanged = onGroupChanged;
    // No host to answer, or a payload that published no choices: the header
    // alone, exactly as before GGU-145.
    if (onChanged == null || data.groups.isEmpty) {
      return HoldingsAllocationHeader(data: data);
    }
    final toggle = HoldingsAllocationToggle(
      groups: data.groups,
      onSelected: onChanged,
      isBusy: isBusy,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < sideBySideFrom
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                HoldingsAllocationHeader(data: data),
                const SizedBox(height: gap),
                toggle,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: HoldingsAllocationHeader(data: data)),
                const SizedBox(width: gap),
                toggle,
              ],
            ),
    );
  }
}
