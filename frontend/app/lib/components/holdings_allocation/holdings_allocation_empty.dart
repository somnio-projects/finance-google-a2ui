import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_center.dart';
import 'package:flutter/material.dart';

/// What the card shows when the backend sent no categories.
///
/// The catalog declares `categories` with `state: "empty"`, so this is a state
/// the contract has. The **design does not draw one** — its third state is a
/// loading skeleton, which is a different thing (a skeleton says "the data is
/// coming"; this says "there is none"). The copy below is therefore **ours**,
/// and `specs/frontend/0007` OD-4 says so rather than letting a reader assume
/// a designer approved it.
///
/// **The total is drawn here, where the ring would have been.** It used to
/// sit in the header and needed no thought; GGU-145 moved it inside the ring,
/// and a card with no ring quietly stopped showing it at all — an empty
/// portfolio has a total, and it is a real figure the backend formatted. The
/// card test that named the figure is what caught it.
class HoldingsAllocationEmpty extends StatelessWidget {
  /// Creates the empty state. [total] and [label] are null on a card whose
  /// header a shell drew, because the total is already on screen there.
  const HoldingsAllocationEmpty({this.total, this.label, super.key});

  /// The sentence shown in place of the ring.
  static const String message = 'No holdings to allocate yet.';

  /// The vertical room the sentence occupies, so the card does not collapse
  /// to a header's height when a portfolio empties.
  static const double verticalPadding = 24;

  /// The gap between the total and the sentence.
  static const double gap = 12;

  /// `total.amount.display`, or null where a shell shows it.
  final String? total;

  /// `total.label`.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final display = total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (display != null) ...<Widget>[
            HoldingsAllocationTotalCenter(display: display, label: label ?? ''),
            const SizedBox(height: gap),
          ],
          Text(
            message,
            style: ChartText.legendLabel(
              AllocationPalette.of(context).legendWeight,
            ),
          ),
        ],
      ),
    );
  }
}
