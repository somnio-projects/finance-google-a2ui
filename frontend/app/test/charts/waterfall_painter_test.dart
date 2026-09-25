import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/charts/waterfall_painter.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'waterfall_harness.dart';

const WaterfallSelection _selected = WaterfallSelection(
  index: 1,
  barFill: Color(0xFF0C6349),
  column: Color(0xFFE8FEF3),
);

void main() {
  group(WaterfallPainter, () {
    WaterfallPainter build({
      WaterfallSelection? selection,
      List<String>? labels,
      double width = 533.37,
    }) => WaterfallPainter(
      layout: WaterfallLayout.of(
        steps: harnessSteps,
        width: width,
        height: 200,
      ),
      palette: ChartTokens.light,
      valueLabels: labels ?? harnessValueDisplays,
      textDirection: TextDirection.ltr,
      selection: selection,
    );

    test('colours a bar by the direction the backend sent', () {
      const p = ChartTokens.light;
      expect(p.barFor(WaterfallStepKind.start), p.barNeutral);
      expect(p.barFor(WaterfallStepKind.gain), p.barGain);
      expect(p.barFor(WaterfallStepKind.loss), p.barLoss);
      expect(p.barFor(WaterfallStepKind.total), p.barTotal);
    });

    test('mutes both totals in text, and only tints a contribution', () {
      const p = ChartTokens.light;
      expect(p.labelFor(WaterfallStepKind.start), p.mutedLabel);
      expect(p.labelFor(WaterfallStepKind.total), p.mutedLabel);
      expect(p.labelFor(WaterfallStepKind.gain), p.barGain);
      expect(p.labelFor(WaterfallStepKind.loss), p.barLoss);
    });

    test('gives the selected bar its own fill and leaves the rest alone', () {
      // AC-2: the selection deepens the tapped bar. Every other bar keeps the
      // mark its direction earned, which is the half that would be easy to
      // break by recolouring the whole chart.
      final painter = build(selection: _selected);
      final bars = painter.layout.bars;
      expect(painter.fillFor(bars[1]), _selected.barFill);
      expect(painter.fillFor(bars[2]), ChartTokens.light.barLoss);
      expect(painter.fillFor(bars.first), ChartTokens.light.barNeutral);
      expect(painter.fillFor(bars.last), ChartTokens.light.barTotal);
    });

    test('leaves every bar its own mark when nothing is selected', () {
      final painter = build();
      for (final bar in painter.layout.bars) {
        expect(painter.fillFor(bar), ChartTokens.light.barFor(bar.step.kind));
      }
    });

    test('keeps the design constants it was measured against', () {
      // The UI Kit rounds all four corners and draws an unbroken connector;
      // the first build did neither (0028 OD-2).
      expect(WaterfallPainter.barRadius, const Radius.circular(4));
      expect(WaterfallPainter.connectorWidth, 1);
    });

    test('repaints when anything it draws changes', () {
      final painter = build();
      expect(painter.shouldRepaint(build()), isFalse);
      expect(painter.shouldRepaint(build(selection: _selected)), isTrue);
      expect(painter.shouldRepaint(build(width: 400)), isTrue);
      expect(
        painter.shouldRepaint(
          build(labels: <String>[for (final _ in harnessSteps) 'x']),
        ),
        isTrue,
      );
    });

    test('repaints when the palette changes', () {
      final light = build();
      final dark = WaterfallPainter(
        layout: light.layout,
        palette: ChartTokens.dark,
        valueLabels: light.valueLabels,
        textDirection: TextDirection.ltr,
      );
      expect(light.shouldRepaint(dark), isTrue);
    });

    testWidgets('paints every bar, connector and label without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(533.37, 200),
            painter: build(selection: _selected),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives fewer labels than steps', (tester) async {
      // A defensive branch, not a contract: the component always supplies
      // one label per step, and a painter that ranged past the list would
      // crash the whole surface rather than lose a label.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(533.37, 200),
            painter: build(labels: const <String>['only one']),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
