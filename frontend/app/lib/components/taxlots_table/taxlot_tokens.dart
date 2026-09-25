import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:flutter/material.dart';

/// The tax-lot palette in each brightness, **measured from the UI Kit**.
///
/// Every value below was read out of
/// `specs/frontend/assets/0027-taxlot-uikit/taxlot-uikit.svg` — a Figma export
/// whose fills are exact — rather than off a rendered page. That matters
/// because the file it replaces was measured from the *earlier* artboard with
/// `getComputedStyle`, honestly, and most of those colours no longer exist in
/// the design (spec `frontend/0027` OD-5). `taxlot_tokens_test.dart` pins each
/// one as a literal, so a drift is someone changing a colour on purpose.
///
/// **Two colours are not in this frame**, and both say where they come from:
///
/// - [TaxLotPalette.loss] — the frame draws four gains and no loss, so the
///   loss colour is the chart palette's `barLoss`. It is written out here
///   rather than read from `ChartTokens` (a field of a `const` object is not
///   a constant expression in Dart) and `taxlot_tokens_test.dart` asserts the
///   two are equal, which is the same arrangement the old file used for the
///   roles the two pages share.
/// - [TaxLotPalette.placeholderBorder] — the empty state is not in this frame
///   either; it takes the same grey as an unticked box.
abstract final class TaxLotTokens {
  /// Light mode, as the kit's light artboards draw it.
  static const TaxLotPalette light = TaxLotPalette(
    surface: Color(0xFFFFFFFF),
    shadow: Color(0x14000000),
    divider: Color(0xFFE1E2E3),
    selectedRow: Color(0xFFEBF1FF),
    checkedBox: Color(0xFF3C90F1),
    checkGlyph: Color(0xFFFFFFFF),
    checkboxBorder: Color(0xFFCBCDD0),
    primaryText: Color(0xFF242425),
    mutedText: Color(0xFF56575B),
    gain: Color(0xFF026E4F),
    loss: Color(0xFFC0362C),
    placeholderBorder: Color(0xFFCBCDD0),
    shortTerm: TaxLotTermColors(
      accent: shortRail,
      chipForeground: Color(0xFF855807),
      chipBackground: Color(0xFFFFF4E0),
    ),
    longTerm: TaxLotTermColors(
      accent: longRail,
      chipForeground: Color(0xFF026E4F),
      chipBackground: Color(0xFFD8FDEB),
    ),
  );

  /// Dark mode, as the kit's dark artboards draw it.
  ///
  /// The geometry is pixel-identical between the artboards — only the palette
  /// changes — which is why one layout serves both.
  static const TaxLotPalette dark = TaxLotPalette(
    surface: Color(0xFF17181C),
    shadow: Color(0x33000000),
    divider: Color(0xFF353A42),
    selectedRow: Color(0xFF17283C),
    checkedBox: Color(0xFF308CF5),
    checkGlyph: Color(0xFFFFFFFF),
    checkboxBorder: Color(0xFF474D58),
    primaryText: Color(0xFFE8E8E9),
    mutedText: Color(0xFFB9BEC6),
    gain: Color(0xFF4ADE9E),
    loss: Color(0xFFFF6B5E),
    placeholderBorder: Color(0xFF474D58),
    shortTerm: TaxLotTermColors(
      accent: shortRail,
      chipForeground: Color(0xFFF2BD62),
      chipBackground: Color(0xFF513F1D),
    ),
    longTerm: TaxLotTermColors(
      accent: longRail,
      chipForeground: Color(0xFF4ADE9E),
      chipBackground: Color(0xFF25483E),
    ),
  );

  /// The long-term rail, **the same in both themes**.
  ///
  /// Not an oversight in the measurement: the kit draws `#2FA584` on the
  /// light and the dark artboard alike, the way the old file held the column
  /// header at one value. It is a constant here so the two palettes cannot
  /// half-change it, and a test asserts the equality.
  static const Color longRail = Color(0xFF2FA584);

  /// The short-term rail, likewise one value across both themes.
  static const Color shortRail = Color(0xFFB8790A);

  /// The palette for [brightness].
  static TaxLotPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
