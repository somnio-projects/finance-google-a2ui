import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The legend's figures sit against the row's right edge.
///
/// `Expanded` and `Flexible` both default to `flex: 1`, so the free space
/// was split 50/50 between the label and the figures; the figures' column
/// is a LOOSE fit, so it shrank to its content and was packed at the START
/// of its half. `crossAxisAlignment: end` could not fix that — the Column is
/// already as wide as its widest child, so aligning inside it is a no-op.
///
/// MEASURED before the fix, two rows at a 400 px width: both blocks began at
/// x=234.5 and ended at 334.5 and 322.0, i.e. 65.5 and 78.0 px short of the
/// edge and not even level with each other. That is what "the last column is
/// pulled left" looks like from the outside (spec frontend/0021 OD-1).
void main() {
  const categories = <AllocationCategory>[
    AllocationCategory(
      key: 'equities',
      label: 'Equities',
      valueDisplay: r'$299,407',
      weightDisplay: '62%',
      weight: 0.62,
      changeDisplay: '+0.9%',
      trend: 'up',
    ),
    AllocationCategory(
      key: 'bonds',
      label: 'Bonds',
      valueDisplay: r'$86,925',
      weightDisplay: '18%',
      weight: 0.18,
      changeDisplay: '-0.2%',
      trend: 'down',
    ),
  ];

  group('$HoldingsAllocationLegend alignment', () {
    testWidgets('every figure ends at the legend\'s right edge', (
      tester,
    ) async {
      await tester.pumpApp(
        const HoldingsAllocationLegend(categories: categories),
        surfaceSize: const Size(400, 400),
      );

      final edge = tester.getRect(find.byType(HoldingsAllocationLegend)).right;
      for (final figure in <String>[
        r'$299,407',
        '▲ +0.9%',
        r'$86,925',
        '▼ -0.2%',
      ]) {
        expect(
          tester.getRect(find.text(figure)).right,
          moreOrLessEquals(edge, epsilon: 0.5),
          reason: '$figure should end at the row edge, not short of it',
        );
      }
    });

    testWidgets('rows of different widths still share that edge', (
      tester,
    ) async {
      // The defect was visible precisely because two rows disagreed: a
      // shorter figure stopped further from the edge than a longer one.
      await tester.pumpApp(
        const HoldingsAllocationLegend(categories: categories),
        surfaceSize: const Size(400, 400),
      );

      expect(
        tester.getRect(find.text(r'$299,407')).right,
        moreOrLessEquals(
          tester.getRect(find.text(r'$86,925')).right,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('a narrow legend still trims rather than overflowing', (
      tester,
    ) async {
      // The `Flexible` is kept, not replaced: the figures must give way on a
      // narrow surface instead of painting past the row.
      await tester.pumpApp(
        const HoldingsAllocationLegend(categories: categories),
        surfaceSize: const Size(220, 400),
      );

      expect(tester.takeException(), isNull);
      final edge = tester.getRect(find.byType(HoldingsAllocationLegend)).right;
      expect(
        tester.getRect(find.text(r'$299,407')).right,
        lessThanOrEqualTo(edge + 0.5),
      );
    });
  });
}
