import 'package:finance_app/charts/chart_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ChartText, () {
    const color = Color(0xFF123456);

    test('uses the sizes and weights measured from the design', () {
      expect(ChartText.value(color).fontSize, 10);
      expect(ChartText.value(color).fontWeight, FontWeight.w500);
      expect(ChartText.axis(color).fontSize, 10);
      expect(ChartText.axis(color).fontWeight, FontWeight.w400);
      expect(ChartText.title(color).fontSize, 14);
      expect(ChartText.chip(color).fontSize, 12);
    });

    test('draws a total heavier than a contribution', () {
      // The UI Kit's hierarchy: the two figures a reader takes away are
      // bolder than the deltas between them (spec frontend/0028 OD-2).
      expect(
        ChartText.total(color).fontWeight!.value,
        greaterThan(ChartText.value(color).fontWeight!.value),
      );
      expect(ChartText.total(color).fontSize, ChartText.value(color).fontSize);
    });

    test('bolds the axis name it wants the eye to land on', () {
      expect(
        ChartText.axisStrong(color).fontWeight!.value,
        greaterThan(ChartText.axis(color).fontWeight!.value),
      );
      expect(
        ChartText.axisStrong(color).fontSize,
        ChartText.axis(color).fontSize,
      );
    });

    test('aligns digits in every figure it draws', () {
      // The functional half of the design's monospace choice, kept without
      // bundling a font. Axis labels are names, so they do not need it.
      expect(ChartText.value(color).fontFeatures, isNotEmpty);
      expect(ChartText.total(color).fontFeatures, isNotEmpty);
      expect(ChartText.chip(color).fontFeatures, isNotEmpty);
      expect(ChartText.axis(color).fontFeatures, isNull);
      expect(ChartText.axisStrong(color).fontFeatures, isNull);
    });
  });

  group('measureLabel', () {
    test('reports a width that grows with the text', () {
      final short = measureLabel(
        r'$1',
        ChartText.value(const Color(0xFF000000)),
        textDirection: TextDirection.ltr,
      );
      final long = measureLabel(
        r'$482,915.00',
        ChartText.value(const Color(0xFF000000)),
        textDirection: TextDirection.ltr,
      );
      expect(long.width, greaterThan(short.width));
      expect(short.height, greaterThan(0));
    });
  });
}
