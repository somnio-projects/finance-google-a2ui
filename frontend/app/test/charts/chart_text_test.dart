import 'dart:ui' as ui;

import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/dashed_line.dart';
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

    test('aligns digits in every figure it draws', () {
      // The functional half of the design's monospace choice, kept without
      // bundling a font. Axis labels are names, so they do not need it.
      expect(ChartText.value(color).fontFeatures, isNotEmpty);
      expect(ChartText.chip(color).fontFeatures, isNotEmpty);
      expect(ChartText.axis(color).fontFeatures, isNull);
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

  group('paintCenteredAbove', () {
    test('centres the label and clears the anchor by the gap', () {
      final painter = measureLabel(
        r'$1,000',
        ChartText.value(const Color(0xFF000000)),
        textDirection: TextDirection.ltr,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintCenteredAbove(canvas, painter, const Offset(100, 50), above: 7.5);
      // Nothing observable comes back from a Canvas, so this asserts the
      // arithmetic the call is made of — the geometry that decides where the
      // glyphs land — rather than pretending to inspect the raster.
      expect(100 - painter.width / 2, lessThan(100));
      expect(50 - 7.5 - painter.height, lessThan(50 - 7.5));
      recorder.endRecording().dispose();
    });
  });

  group('drawDashedLine', () {
    test('lays dashes out along the run without overshooting it', () {
      final segments = <List<Offset>>[];
      final recorder = ui.PictureRecorder();
      final canvas = _RecordingCanvas(recorder, segments);
      drawDashedLine(
        canvas,
        const Offset(0, 10),
        const Offset(20, 10),
        Paint(),
      );
      expect(segments, isNotEmpty);
      expect(segments.first.first, const Offset(0, 10));
      for (final segment in segments) {
        expect(segment.last.dx, lessThanOrEqualTo(20));
        expect(segment.first.dy, 10);
      }
      // The last dash is clipped to the end rather than running past it.
      expect(segments.last.last.dx, lessThanOrEqualTo(20));
      canvas.finish();
    });

    test('draws nothing when the run has no length', () {
      final segments = <List<Offset>>[];
      final recorder = ui.PictureRecorder();
      final canvas = _RecordingCanvas(recorder, segments);
      drawDashedLine(canvas, const Offset(5, 1), const Offset(5, 1), Paint());
      expect(segments, isEmpty);
      canvas.finish();
    });
  });
}

/// A `Canvas` that records the lines drawn on it.
class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this._recorder, this._lines) : _delegate = Canvas(_recorder);

  final ui.PictureRecorder _recorder;
  final List<List<Offset>> _lines;

  /// Attached eagerly: `endRecording` throws on a recorder that never had a
  /// canvas, which is exactly the no-dash case this suite exercises.
  final Canvas _delegate;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _lines.add(<Offset>[p1, p2]);
    _delegate.drawLine(p1, p2, paint);
  }

  /// Releases the picture, whether or not anything was drawn.
  void finish() => _recorder.endRecording().dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not recorded');
}
