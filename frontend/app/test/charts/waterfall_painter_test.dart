import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/charts/waterfall_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'waterfall_harness.dart';

void main() {
  group(WaterfallPainter, () {
    WaterfallPainter build({
      int? selectedIndex,
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
      selectedIndex: selectedIndex,
    );

    test('colours a bar by the direction the backend sent', () {
      const p = ChartTokens.light;
      expect(p.barFor(WaterfallStepKind.start), p.barNeutral);
      expect(p.barFor(WaterfallStepKind.gain), p.barGain);
      expect(p.barFor(WaterfallStepKind.loss), p.barLoss);
      expect(p.barFor(WaterfallStepKind.total), p.barTotal);
    });

    test('mutes both totals in text, and only tints a contribution', () {
      // Measured: the design draws both opening and closing figures in
      // #5F6169. The closing total's *bar* is the accent, its *label* is
      // not — deriving the label colour from the bar colour got that wrong.
      const p = ChartTokens.light;
      expect(p.labelFor(WaterfallStepKind.start), p.mutedLabel);
      expect(p.labelFor(WaterfallStepKind.total), p.mutedLabel);
      expect(p.labelFor(WaterfallStepKind.gain), p.barGain);
      expect(p.labelFor(WaterfallStepKind.loss), p.barLoss);
    });

    test('keeps the design constants it was measured against', () {
      expect(WaterfallPainter.barRadius, const Radius.circular(4));
      expect(WaterfallPainter.connectorWidth, 1.5);
      expect(WaterfallPainter.labelGap, 7.5);
    });

    test('repaints when anything it draws changes', () {
      final painter = build();
      expect(painter.shouldRepaint(build()), isFalse);
      expect(painter.shouldRepaint(build(selectedIndex: 2)), isTrue);
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
            painter: build(selectedIndex: 1),
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

    testWidgets('drops a value label that will not fit its band', (
      tester,
    ) async {
      // The design does the same thing: its 245 px artboard shows no value
      // labels. The rule is the measured text width, not a breakpoint.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(120, 200),
            painter: build(width: 120),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
