import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
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
/// The title and the total above it still render: an empty portfolio has a
/// total, and it is a real figure the backend formatted.
class HoldingsAllocationEmpty extends StatelessWidget {
  /// Creates the empty state.
  const HoldingsAllocationEmpty({super.key});

  /// The sentence shown in place of the ring.
  static const String message = 'No holdings to allocate yet.';

  /// The vertical room the sentence occupies, so the card does not collapse
  /// to a header's height when a portfolio empties.
  static const double verticalPadding = 24;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: verticalPadding),
    child: Text(
      message,
      style: ChartText.legendLabel(AllocationPalette.of(context).legendWeight),
    ),
  );
}
