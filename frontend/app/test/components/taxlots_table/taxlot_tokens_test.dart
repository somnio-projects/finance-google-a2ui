import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins every value measured off the design's two artboards.
///
/// GGU-55 found two of five informally circulated colours wrong, so these
/// were read with `getComputedStyle` on the rendered page and are asserted
/// here as literals. A literal is the point: if it drifts, someone changed
/// a colour and has to say so.
void main() {
  group('TaxLotTokens', () {
    test('light matches the L1 artboard', () {
      const light = TaxLotTokens.light;
      expect(light.surface, const Color(0xFFFDFBFF));
      expect(light.border, const Color(0xFFEAE7F0));
      expect(light.selectedSurface, const Color(0xFFEEF0FF));
      expect(light.selectedAccent, const Color(0xFF4F5DFF));
      expect(light.footerSurface, const Color(0xFFF5F3FB));
      expect(light.primaryText, const Color(0xFF1A1B20));
      expect(light.figureText, const Color(0xFF44464E));
      expect(light.labelText, const Color(0xFF5F6169));
      expect(light.mutedText, const Color(0xFF8A8D96));
      expect(light.checkboxBorder, const Color(0xFFC4C6D0));
      expect(light.placeholderBorder, const Color(0xFFC4C6D0));
    });

    test('light draws short-term amber and long-term teal', () {
      const light = TaxLotTokens.light;
      expect(light.shortTerm.accent, const Color(0xFFF0A52E));
      expect(light.shortTerm.chipForeground, const Color(0xFF8A5A10));
      expect(light.shortTerm.chipBackground, const Color(0xFFFDF0DC));
      expect(light.shortTerm.chipBorder, const Color(0xFFF0D9A8));
      expect(light.longTerm.accent, const Color(0xFF0F9D8F));
      expect(light.longTerm.chipForeground, const Color(0xFF0C6A60));
      expect(light.longTerm.chipBackground, const Color(0xFFDCEFEC));
      expect(light.longTerm.chipBorder, const Color(0xFFB8DDD6));
    });

    test('dark matches the D1 artboard', () {
      const dark = TaxLotTokens.dark;
      expect(dark.surface, const Color(0xFF15161C));
      expect(dark.border, const Color(0xFF24252D));
      expect(dark.selectedSurface, const Color(0xFF20223A));
      expect(dark.selectedAccent, const Color(0xFF7A83FF));
      expect(dark.footerSurface, const Color(0xFF101017));
      expect(dark.primaryText, const Color(0xFFE5E1E9));
      expect(dark.figureText, const Color(0xFFC9CBD4));
      expect(dark.labelText, const Color(0xFFA4A6B0));
      expect(dark.checkboxBorder, const Color(0xFF45464F));
      expect(dark.checkboxGlyph, const Color(0xFF0B0C10));
      expect(dark.placeholderBorder, const Color(0xFF3A3B44));
    });

    test('dark draws short-term amber and long-term teal', () {
      const dark = TaxLotTokens.dark;
      expect(dark.shortTerm.accent, const Color(0xFFFFBF5C));
      expect(dark.shortTerm.chipForeground, const Color(0xFFFFCF7A));
      expect(dark.shortTerm.chipBackground, const Color(0xFF2E2410));
      expect(dark.shortTerm.chipBorder, const Color(0xFF4A3A18));
      expect(dark.longTerm.accent, const Color(0xFF3FC8B8));
      expect(dark.longTerm.chipForeground, const Color(0xFF6FE0D2));
      expect(dark.longTerm.chipBackground, const Color(0xFF12302C));
      expect(dark.longTerm.chipBorder, const Color(0xFF1F4A44));
    });

    test('holds the column header at one value across both themes', () {
      // Not an oversight in the measurement: the designer keeps #8A8D96 on
      // both artboards, which is the one colour that does not flip.
      expect(TaxLotTokens.dark.mutedText, TaxLotTokens.light.mutedText);
    });

    test('agrees with the chart palette on every shared role', () {
      // The two palettes are separate files on purpose — coupling them
      // would mean editing a chart's file to add a component (ADR-L D-3) —
      // and they were measured independently, off two different pages.
      // This is what stops them drifting while staying separate.
      expect(TaxLotTokens.light.gain, ChartTokens.light.barGain);
      expect(TaxLotTokens.light.loss, ChartTokens.light.barLoss);
      expect(TaxLotTokens.light.surface, ChartTokens.light.surface);
      expect(TaxLotTokens.light.border, ChartTokens.light.border);
      expect(TaxLotTokens.light.selectedAccent, ChartTokens.light.barTotal);
      expect(TaxLotTokens.dark.gain, ChartTokens.dark.barGain);
      expect(TaxLotTokens.dark.loss, ChartTokens.dark.barLoss);
      expect(TaxLotTokens.dark.surface, ChartTokens.dark.surface);
      expect(TaxLotTokens.dark.border, ChartTokens.dark.border);
      expect(TaxLotTokens.dark.selectedAccent, ChartTokens.dark.barTotal);
    });

    test('forBrightness picks the artboard the theme is in', () {
      expect(TaxLotTokens.forBrightness(Brightness.light), TaxLotTokens.light);
      expect(TaxLotTokens.forBrightness(Brightness.dark), TaxLotTokens.dark);
    });
  });
}
