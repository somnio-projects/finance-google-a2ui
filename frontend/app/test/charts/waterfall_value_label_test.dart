import 'dart:ui' as ui;

import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/waterfall_value_label.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'waterfall_harness.dart';

/// The figure above a bar: whether it is drawn, and where it lands.
///
/// The placement arithmetic is proved on its own in
/// `finance_charts/test/src/waterfall_columns_test.dart`; this asserts that
/// the painter *uses* it, and that it drops what will not fit.
void main() {
  WaterfallLayout layout(double width) =>
      WaterfallLayout.of(steps: harnessSteps, width: width, height: 200);

  /// Where the figure for [bar] was painted, or null when it was dropped.
  Offset? paintAt(WaterfallBar bar, String text, WaterfallLayout plot) {
    final canvas = _ParagraphCanvas();
    paintWaterfallValueLabel(
      canvas,
      bar: bar,
      text: text,
      palette: ChartTokens.light,
      textDirection: TextDirection.ltr,
      bandScale: plot.bandScale,
    );
    canvas.finish();
    return canvas.offsets.isEmpty ? null : canvas.offsets.single;
  }

  group('paintWaterfallValueLabel', () {
    test('centres a figure that fits its band, above the bar', () {
      final plot = layout(700);
      final bar = plot.bars[1];
      final at = paintAt(bar, r'$10,230.00', plot)!;
      final width = measureLabel(
        r'$10,230.00',
        ChartText.value(ChartTokens.light.barGain),
        textDirection: TextDirection.ltr,
      ).width;
      expect(at.dx + width / 2, closeTo(bar.rect.topCenter.x, 0.01));
      expect(at.dy, lessThan(bar.rect.top - waterfallLabelGap));
    });

    test('never lets a figure leave the plot, at any width', () {
      // Universally quantified rather than aimed at the two totals: the two
      // rules together — drop what is wider than its band, clamp what is not
      // — make this a property of every band at every width, and a property
      // is what survives the next change to either rule (0028 OD-5).
      for (final width in <double>[700, 533.37, 420, 300, 180]) {
        final plot = layout(width);
        for (var index = 0; index < plot.bars.length; index++) {
          final at = paintAt(
            plot.bars[index],
            harnessValueDisplays[index],
            plot,
          );
          if (at == null) continue;
          final drawn = measureLabel(
            harnessValueDisplays[index],
            ChartText.total(ChartTokens.light.title),
            textDirection: TextDirection.ltr,
          ).width;
          expect(at.dx, greaterThanOrEqualTo(-0.01), reason: 'band $index');
          expect(
            at.dx + drawn,
            lessThanOrEqualTo(width + 0.01),
            reason: 'band $index at $width',
          );
        }
      }
    });

    test('drops a figure wider than its band', () {
      // The design's narrow artboard shows no value labels at all; the rule
      // is the measured width and not a breakpoint.
      expect(paintAt(layout(120).bars[1], r'$10,230.00', layout(120)), isNull);
    });

    test('draws every figure of a real walk at a width that fits', () {
      final plot = layout(700);
      for (var index = 0; index < plot.bars.length; index++) {
        expect(
          paintAt(plot.bars[index], harnessValueDisplays[index], plot),
          isNotNull,
          reason: 'band $index dropped its figure',
        );
      }
    });

    test('keeps the gap the design was measured at', () {
      expect(waterfallLabelGap, 7.5);
    });
  });
}

/// A `Canvas` that records where paragraphs were painted.
///
/// A `TextPainter` reports nothing observable, so this is how a test sees
/// whether a figure was drawn and at what offset. Everything else the painter
/// asks of the canvas is accepted and ignored.
class _ParagraphCanvas implements Canvas {
  factory _ParagraphCanvas() {
    final recorder = ui.PictureRecorder();
    return _ParagraphCanvas._(recorder, Canvas(recorder));
  }

  _ParagraphCanvas._(this._recorder, this._delegate);

  final ui.PictureRecorder _recorder;

  final Canvas _delegate;

  /// Where each paragraph landed, in paint order.
  final List<Offset> offsets = <Offset>[];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    offsets.add(offset);
    _delegate.drawParagraph(paragraph, offset);
  }

  /// Releases the picture, whether or not anything was drawn.
  void finish() {
    if (_recorder.isRecording) _recorder.endRecording().dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
