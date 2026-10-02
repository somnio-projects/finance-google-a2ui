import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_toggle.dart';
import 'package:flutter/material.dart';

/// The card's whole header block: the title row, and the grouping toggle
/// under it.
///
/// **The toggle is on its own line at every width**, which is a measurement
/// rather than a choice: the Figma `Header` frame is `Flujo Vertical` with
/// `Espacio spacing/12` on both the 360 and the 640 artboard. The first
/// version of this file put the two side by side above an invented 480 px
/// breakpoint, and the breakpoint was invented precisely because nobody had
/// looked — it ellipsised the total in the Assistant until a test caught it.
/// The design had answered the question all along.
///
/// The other rule it carries: **the toggle is drawn only where a tap can be
/// honoured.** A host that cannot re-request gives the card no
/// `onGroupChanged`, and a control that looks live and does nothing is worse
/// than no control (spec frontend/0026).
class HoldingsAllocationHeaderRow extends StatelessWidget {
  /// Creates the block.
  const HoldingsAllocationHeaderRow({
    required this.data,
    this.onGroupChanged,
    this.isBusy = false,
    super.key,
  });

  /// The gap between the title row and the toggle (`spacing/12`).
  static const double gap = 12;

  /// The model.
  final AllocationData data;

  /// Called with a grouping's `value`, or null where none can be honoured.
  final ValueChanged<String>? onGroupChanged;

  /// True while a re-render is in flight.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final onChanged = onGroupChanged;
    // No host to answer, or a payload that published no choices: the title
    // row alone, exactly as before GGU-145.
    if (onChanged == null || data.groups.isEmpty) {
      return HoldingsAllocationHeader(data: data);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HoldingsAllocationHeader(data: data),
        const SizedBox(height: gap),
        HoldingsAllocationToggle(
          groups: data.groups,
          onSelected: onChanged,
          isBusy: isBusy,
        ),
      ],
    );
  }
}
