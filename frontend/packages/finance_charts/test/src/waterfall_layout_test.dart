import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

import '../design_reference.dart';

void main() {
  group(WaterfallLayout, () {
    late WaterfallLayout layout;

    setUp(() {
      layout = WaterfallLayout.of(
        steps: designSteps,
        width: designPlotWidth,
        height: designPlotHeight,
      );
    });

    test('places every bar where the design draws it', () {
      // The pixel-perfect claim, asserted rather than eyeballed: seven bar
      // tops and seven heights against the measured DOM, to the 0.1 px the
      // browser reports. Change the scale's domain and all fourteen fail.
      for (var index = 0; index < designSteps.length; index++) {
        final rect = layout.bars[index].rect;
        expect(
          rect.top,
          closeTo(designBarTops[index], 0.1),
          reason: 'bar $index top',
        );
        expect(
          rect.height,
          closeTo(designBarHeights[index], 0.1),
          reason: 'bar $index height',
        );
      }
    });

    test('draws the bars at the design width, centred in their bands', () {
      expect(layout.bandScale.barWidth, 44);
      for (final bar in layout.bars) {
        expect(bar.rect.width, 44);
        expect(
          bar.rect.topCenter.x,
          closeTo(layout.bandScale.center(bar.index), 1e-9),
        );
      }
    });

    test('stands both totals on the axis floor', () {
      expect(layout.bars.first.rect.bottom, designPlotHeight);
      expect(layout.bars.last.rect.bottom, designPlotHeight);
    });

    test('floats a contribution between the two running totals', () {
      // The gain after the opener: it starts where the opener's bar ends.
      expect(
        layout.bars[1].rect.bottom,
        closeTo(layout.bars[0].rect.top, 1e-9),
      );
      // The first loss drops from the level the gain before it reached.
      expect(layout.bars[4].rect.top, closeTo(layout.bars[3].rect.top, 1e-9));
    });

    test('runs one connector between each pair of neighbours', () {
      expect(layout.connectors, hasLength(designSteps.length - 1));
      for (var index = 0; index < layout.connectors.length; index++) {
        final connector = layout.connectors[index];
        expect(connector.from.y, connector.to.y, reason: 'stays horizontal');
        expect(connector.from.x, layout.bandScale.center(index));
        expect(connector.to.x, layout.bandScale.center(index + 1));
        // It leaves at the running total the step it follows arrived at.
        expect(
          connector.from.y,
          closeTo(layout.valueScale(designSteps[index].level), 1e-9),
        );
      }
    });

    test('derives the axis from the levels it was given', () {
      expect(layout.valueScale.domainMin, 478000);
      expect(layout.valueScale.domainMax, 484000);
    });

    test('lays out nothing for an empty walk without dividing by zero', () {
      // `buckets` defaults to `[]` in the contract, and a portfolio that did
      // not move is a real answer, not an error.
      final empty = WaterfallLayout.of(
        steps: const <WaterfallStep>[],
        width: 300,
        height: 200,
      );
      expect(empty.bars, isEmpty);
      expect(empty.connectors, isEmpty);
      expect(empty.bandScale.bandWidth, 0);
    });

    test('lays out a single total on its own', () {
      final single = WaterfallLayout.of(
        steps: const <WaterfallStep>[
          WaterfallStep(key: 'end', kind: WaterfallStepKind.total, level: 10),
        ],
        width: 100,
        height: 200,
      );
      expect(single.bars, hasLength(1));
      expect(single.connectors, isEmpty);
      expect(single.bars.single.rect.bottom, 200);
    });

    test('is equal to another layout over the same inputs', () {
      expect(
        layout,
        equals(
          WaterfallLayout.of(
            steps: designSteps,
            width: designPlotWidth,
            height: designPlotHeight,
          ),
        ),
      );
    });
  });
}
