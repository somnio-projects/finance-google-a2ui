import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_app/theme/activity_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins every value measured off the UI Kit's artboards (AC-5).
///
/// A literal is the point: if one drifts, somebody changed a colour and has
/// to say so. They were read out of the Figma export's own fills, which is
/// exact — the file this replaces was measured with `getComputedStyle` on a
/// rendered page, honestly, and most of those values are no longer in the
/// design at all (spec `frontend/0027` OD-5).
void main() {
  group('TaxLotTokens', () {
    test('light matches the kit', () {
      const light = TaxLotTokens.light;
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.divider, const Color(0xFFE1E2E3));
      expect(light.selectedRow, const Color(0xFFEBF1FF));
      expect(light.checkedBox, const Color(0xFF3C90F1));
      expect(light.checkGlyph, const Color(0xFFFFFFFF));
      expect(light.checkboxBorder, const Color(0xFFCBCDD0));
      expect(light.primaryText, const Color(0xFF242425));
      expect(light.mutedText, const Color(0xFF56575B));
      expect(light.gain, const Color(0xFF026E4F));
      expect(light.placeholderBorder, light.checkboxBorder);
    });

    test('light draws short-term amber and long-term teal', () {
      const light = TaxLotTokens.light;
      expect(light.shortTerm.chipForeground, const Color(0xFF855807));
      expect(light.shortTerm.chipBackground, const Color(0xFFFFF4E0));
      expect(light.longTerm.chipForeground, const Color(0xFF026E4F));
      expect(light.longTerm.chipBackground, const Color(0xFFD8FDEB));
    });

    test('dark matches the kit', () {
      const dark = TaxLotTokens.dark;
      expect(dark.surface, const Color(0xFF17181C));
      expect(dark.divider, const Color(0xFF353A42));
      expect(dark.selectedRow, const Color(0xFF17283C));
      expect(dark.checkedBox, const Color(0xFF308CF5));
      expect(dark.checkboxBorder, const Color(0xFF474D58));
      expect(dark.primaryText, const Color(0xFFE8E8E9));
      expect(dark.mutedText, const Color(0xFFB9BEC6));
      expect(dark.gain, const Color(0xFF4ADE9E));
      expect(dark.placeholderBorder, dark.checkboxBorder);
    });

    test('dark draws short-term amber and long-term teal', () {
      const dark = TaxLotTokens.dark;
      expect(dark.shortTerm.chipForeground, const Color(0xFFF2BD62));
      expect(dark.shortTerm.chipBackground, const Color(0xFF513F1D));
      expect(dark.longTerm.chipForeground, const Color(0xFF4ADE9E));
      expect(dark.longTerm.chipBackground, const Color(0xFF25483E));
    });

    test('holds both term rails at one value across the two themes', () {
      // Not an oversight in the measurement: the kit draws `#2FA584` and
      // `#B8790A` on the light and the dark artboard alike, which is why
      // they are constants both palettes read (OD-5).
      expect(TaxLotTokens.light.longTerm.accent, TaxLotTokens.longRail);
      expect(TaxLotTokens.dark.longTerm.accent, TaxLotTokens.longRail);
      expect(TaxLotTokens.light.shortTerm.accent, TaxLotTokens.shortRail);
      expect(TaxLotTokens.dark.shortTerm.accent, TaxLotTokens.shortRail);
      expect(TaxLotTokens.longRail, const Color(0xFF2FA584));
      expect(TaxLotTokens.shortRail, const Color(0xFFB8790A));
    });

    test('agrees with the chart palette on loss, which this frame omits', () {
      // The kit's tax-lot frame draws four gains and no loss, so the loss
      // colour is borrowed rather than measured. This is what keeps the
      // borrowing honest while the two files stay separate — coupling them
      // would mean editing a chart's file to change a component (ADR-L D-3).
      expect(TaxLotTokens.light.loss, ChartTokens.light.barLoss);
      expect(TaxLotTokens.dark.loss, ChartTokens.dark.barLoss);
    });

    test('names the two places the kit and the chart page disagree', () {
      // Asserted, not deleted: `frontend/0007` OD-2 records the same shape
      // for the allocation ramp. Design owns the merge (OQ-6); the client
      // does not get to pick a winner by editing another page's tokens.
      expect(TaxLotTokens.light.gain, isNot(ChartTokens.light.barGain));
      expect(TaxLotTokens.dark.gain, ChartTokens.dark.barGain);
      expect(
        TaxLotTokens.light.longTerm.chipBackground,
        isNot(activityTokensLight.longBadge),
      );
      expect(
        TaxLotTokens.dark.longTerm.chipForeground,
        activityTokensDark.longBadgeText,
      );
    });

    test('forBrightness picks the artboard the theme is in', () {
      expect(TaxLotTokens.forBrightness(Brightness.light), TaxLotTokens.light);
      expect(TaxLotTokens.forBrightness(Brightness.dark), TaxLotTokens.dark);
    });
  });
}
