import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/waterfall_axis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import 'waterfall_harness.dart';

void main() {
  group(WaterfallAxis, () {
    Widget subject({int? selectedIndex, List<String>? labels}) => SizedBox(
      width: 560,
      child: WaterfallAxis(
        steps: harnessSteps,
        labels: labels ?? harnessAxisLabels,
        selectedIndex: selectedIndex,
      ),
    );

    testWidgets('bolds the closing total and mutes everything else', (
      tester,
    ) async {
      // AC-2: the UI Kit's `Now` is the only bold name until something is
      // selected. Decided from the step's kind, never from the label's text.
      await tester.pumpApp(subject());
      final closing = tester.widget<Text>(find.text('Market value'));
      final other = tester.widget<Text>(find.text('Bitcoin'));
      expect(closing.style?.color, ChartTokens.light.title);
      expect(closing.style?.fontWeight, FontWeight.w700);
      expect(other.style?.color, ChartTokens.light.mutedLabel);
      expect(other.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('bolds the selected name as well', (tester) async {
      await tester.pumpApp(subject(selectedIndex: 1));
      final selected = tester.widget<Text>(find.text('Bitcoin'));
      expect(selected.style?.color, ChartTokens.light.title);
      expect(selected.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('takes the dark palette under the dark theme', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      expect(
        tester.widget<Text>(find.text('Market value')).style?.color,
        ChartTokens.dark.title,
      );
      expect(
        tester.widget<Text>(find.text('Bitcoin')).style?.color,
        ChartTokens.dark.mutedLabel,
      );
    });

    testWidgets('emphasises nothing for a label with no step behind it', (
      tester,
    ) async {
      // The two lists are separate arguments and a caller may pass a longer
      // label list. Reading past the walk would throw and take the surface
      // with it, so the extra name is simply muted.
      await tester.pumpApp(
        subject(labels: <String>[...harnessAxisLabels, 'Orphan']),
      );
      expect(
        tester.widget<Text>(find.text('Orphan')).style?.color,
        ChartTokens.light.mutedLabel,
      );
    });

    test('keeps the gap the design was measured at', () {
      expect(WaterfallAxis.gap, 8);
    });
  });
}
