import 'package:finance_app/charts/sparkline_chart.dart';
import 'package:finance_app/charts/sparkline_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(SparklineChart, () {
    const values = <double>[1, 3, 2, 5, 4];

    testWidgets('paints one point per value at the design height', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: SizedBox(
            width: 350,
            child: SparklineChart(values: values, color: Color(0xFF12805C)),
          ),
        ),
      );
      final paint = tester.widget<CustomPaint>(
        find.byKey(SparklineChart.plotKey),
      );
      final painter = paint.painter! as SparklinePainter;
      expect(painter.layout.points, hasLength(values.length));
      expect(tester.getSize(find.byType(SparklineChart)).height, 52);
    });

    testWidgets('draws nothing, and throws nothing, for no values', (
      tester,
    ) async {
      await tester.pumpApp(
        const SizedBox(
          width: 350,
          child: SparklineChart(values: <double>[], color: Color(0xFF12805C)),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('repaints when the layout or colour changes, and only then', () {
      final layout = SparklineLayout.of(values: values, width: 10, height: 5);
      const green = Color(0xFF12805C);
      final painter = SparklinePainter(layout: layout, color: green);
      expect(
        painter.shouldRepaint(SparklinePainter(layout: layout, color: green)),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          SparklinePainter(
            layout: SparklineLayout.of(values: values, width: 20, height: 5),
            color: green,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          SparklinePainter(layout: layout, color: const Color(0xFF000000)),
        ),
        isTrue,
      );
    });
  });
}
