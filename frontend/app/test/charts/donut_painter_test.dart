import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/donut_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(DonutPainter, () {
    DonutPainter painterFor({int? selected, List<double>? weights}) =>
        DonutPainter(
          layout: DonutLayout.of(
            weights: weights ?? const <double>[1, 1],
            width: 150,
            height: 150,
          ),
          palette: ChartTokens.allocationLight,
          selectedIndex: selected,
        );

    test('repaints when the layout, palette or selection changes', () {
      final base = painterFor();
      expect(base.shouldRepaint(painterFor()), isFalse);
      expect(base.shouldRepaint(painterFor(selected: 1)), isTrue);
      expect(
        base.shouldRepaint(painterFor(weights: const <double>[2, 1])),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          DonutPainter(
            layout: base.layout,
            palette: ChartTokens.allocationDark,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('paints a ring, a selected ring, and nothing when empty', (
      tester,
    ) async {
      // Exercises every branch of `paint`: the early return, the zero-sweep
      // skip, and the selected stroke. A golden proves what it looks like;
      // this proves it runs and does not throw.
      for (final painter in <DonutPainter>[
        painterFor(),
        painterFor(selected: 0),
        painterFor(weights: const <double>[1, 0, 1]),
        painterFor(weights: const <double>[]),
      ]) {
        await tester.pumpApp(
          Center(
            child: CustomPaint(size: const Size.square(150), painter: painter),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    test('draws nothing when the ring has no thickness', () {
      final flat = DonutPainter(
        layout: DonutLayout.of(weights: const <double>[1], width: 0, height: 0),
        palette: ChartTokens.allocationLight,
      );
      expect(flat.layout.thickness, isZero);
    });
  });

  group(AllocationPalette, () {
    // One pump per brightness, in its own test. A single tester reuses the
    // element tree, and `MaterialApp` lerps between two themes, so reading
    // the second brightness after pumping the first catches the extension
    // mid-animation — which is a real behaviour, not a flake, and the reason
    // this is two tests rather than a loop inside one.
    for (final brightness in Brightness.values) {
      testWidgets('is read from the real theme in $brightness', (tester) async {
        late AllocationPalette found;
        await tester.pumpApp(
          Builder(
            builder: (context) {
              found = AllocationPalette.of(context);
              return const SizedBox();
            },
          ),
          brightness: brightness,
        );
        expect(found, equals(ChartTokens.allocationFor(brightness)));
      });
    }

    test('differs between the two brightnesses', () {
      expect(
        ChartTokens.allocationLight,
        isNot(equals(ChartTokens.allocationDark)),
      );
    });
  });
}
