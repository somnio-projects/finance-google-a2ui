import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// GGU-147 — the app sets the typeface every artboard sets.
///
/// **These assert the wiring, not the glyphs, and that is the whole of what a
/// test here can honestly do.** `flutter test` draws every character of every
/// family as the test font's em square, so a suite cannot tell Plex from
/// Roboto and neither can a golden (`frontend/testing.md` §6). Whether the
/// letters are really Plex is proved by looking at the running app.
///
/// What *can* regress silently is the second half of §3 of spec 0035: a
/// `CustomPainter` inherits no theme, so `ThemeData.fontFamily` reaches every
/// `Text` and not one painted label. Half-applied, that reads as a font bug
/// rather than as a missing line.
void main() {
  group('the design typeface', () {
    test('is the family the pubspec declares', () {
      // Spelled out once here so a rename in `pubspec.yaml` that misses the
      // constant is a red test rather than a silent fallback to the platform
      // default — Flutter draws an unknown family without complaining.
      expect(designFontFamily, 'IBMPlexSans');
      expect(AppTheme.fontFamily, designFontFamily);
    });

    test('reaches every widget through both themes', () {
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, designFontFamily);
        expect(theme.textTheme.titleLarge?.fontFamily, designFontFamily);
      }
    });

    test('reaches every painted label, which no theme could do', () {
      // One assertion per style `ChartText` builds: this is the list a
      // painter draws from, and a style added without the family would put
      // one label on a card in the platform default.
      const ink = Color(0xFF000000);
      final painted = <String, TextStyle>{
        'value': ChartText.value(ink),
        'total': ChartText.total(ink),
        'axis': ChartText.axis(ink),
        'axisStrong': ChartText.axisStrong(ink),
        'title': ChartText.title(ink),
        'headlineFigure': ChartText.headlineFigure(ink),
        'legendLabel': ChartText.legendLabel(ink),
        'legendFigure': ChartText.legendFigure(ink, size: 12),
        'chip': ChartText.chip(ink),
      };

      for (final entry in painted.entries) {
        expect(
          entry.value.fontFamily,
          designFontFamily,
          reason: 'ChartText.${entry.key} is painted, so it names the family',
        );
      }
    });

    testWidgets('a chart palette is still reachable under the theme', (
      tester,
    ) async {
      // Guards the import direction spec 0035 §3 argues for: `app_typeface`
      // is a leaf precisely so `AppTheme` can keep reaching down into the
      // chart palettes. A cycle would not compile, but it would be fixed by
      // moving the constant somewhere worse, so the shape is asserted.
      late ChartPalette palette;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              palette = ChartPalette.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(palette.title, isNotNull);
    });
  });
}
