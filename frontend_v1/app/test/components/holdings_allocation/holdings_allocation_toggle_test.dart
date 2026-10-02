import 'package:finance_app/components/holdings_allocation/allocation_group.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_toggle_harness.dart';

/// GGU-145 — the grouping toggle the design draws above the donut.
///
/// What it guards is the seam rather than the pixels: the words and the lit
/// segment are the backend's, the value goes back through the declared
/// option, and the control is drawn only where a tap can be honoured.
void main() {
  group(HoldingsAllocationToggle, () {
    testWidgets('shows one segment per grouping the payload published', (
      tester,
    ) async {
      final published = allocationData().groups;
      await tester.pumpApp(
        editableAllocation(<SentOption>[]),
        surfaceSize: desktopSurface,
      );

      expect(published, isNotEmpty);
      for (final group in published) {
        expect(find.text(group.label), findsOneWidget);
      }
    });

    testWidgets("the words are the backend's, never an enum value", (
      tester,
    ) async {
      // A client that prettified `asset_class` into "By asset class" would be
      // authoring copy for a value the server owns (N-1), and this is what
      // would catch it: the value must not be on screen.
      await tester.pumpApp(
        editableAllocation(<SentOption>[]),
        surfaceSize: desktopSurface,
      );

      for (final group in allocationData().groups) {
        expect(find.text(group.value), findsNothing);
      }
    });

    testWidgets('sends the tapped grouping back through the declared option', (
      tester,
    ) async {
      final sent = <SentOption>[];
      await tester.pumpApp(
        editableAllocation(sent),
        surfaceSize: desktopSurface,
      );
      final other = allocationData().groups.firstWhere(
        (group) => !group.selected,
      );

      await tester.tap(find.text(other.label));
      await tester.pump();

      expect(sent, <SentOption>[
        (option: HoldingsAllocationComponent.groupOption, value: other.value),
      ]);
    });

    testWidgets('draws no toggle where no host can honour a tap', (
      tester,
    ) async {
      // The read-only case: a control that looks live and does nothing is
      // worse than no control (spec frontend/0026's rule for the ticket).
      await tester.pumpApp(
        Center(child: HoldingsAllocationCard(data: allocationData())),
        surfaceSize: desktopSurface,
      );

      expect(find.byType(HoldingsAllocationToggle), findsNothing);
    });

    testWidgets('draws no toggle when the payload published no choices', (
      tester,
    ) async {
      // `groups` defaults to empty, which is a payload the contract allows
      // and a card built from a literal in a golden carries.
      await tester.pumpApp(
        Center(
          child: HoldingsAllocationCard(
            data: const AllocationData(
              title: 'Allocation',
              totalLabel: 'Total market value',
              totalDisplay: r'$1.00',
              categories: <AllocationCategory>[],
            ),
            onGroupChanged: (_) {},
          ),
        ),
        surfaceSize: desktopSurface,
      );

      expect(find.byType(HoldingsAllocationToggle), findsNothing);
    });

    testWidgets(
      'stops answering while the re-render it asked for is in flight',
      (tester) async {
        final sent = <SentOption>[];
        const groups = <AllocationGroup>[
          AllocationGroup(
            value: 'holding',
            label: 'By holding',
            selected: true,
          ),
          AllocationGroup(value: 'sector', label: 'By sector', selected: false),
        ];
        await tester.pumpApp(
          Center(
            child: HoldingsAllocationToggle(
              groups: groups,
              isBusy: true,
              onSelected: (value) =>
                  sent.add((option: 'group_by', value: value)),
            ),
          ),
          surfaceSize: desktopSurface,
        );

        await tester.tap(find.text('By sector'));
        await tester.pump();

        // The figures beside it are still the previous grouping's, so a second
        // tap would ask about a card nobody is looking at yet.
        expect(sent, isEmpty);
      },
    );
  });
}
