import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:flutter/material.dart';

/// The tax-lot palette in each brightness, **measured from the design**.
///
/// Every value below was read out of `Catalog - Tax-Lot Table.html` with
/// `getComputedStyle` on the rendered artboards, not copied from a token
/// list — GGU-55 found two of five informally circulated values wrong, so
/// this table is measured the same way and pinned by
/// `taxlot_tokens_test.dart`, which fails on any drift.
///
/// The four semantic roles the two pages share — gain, loss, the selected
/// accent and the surfaces — were measured here **independently** and agree
/// with `ChartTokens` to the byte; `::agrees with the chart palette on every
/// shared role` asserts that, so the two files cannot drift apart while
/// staying separate (a chart palette is not a table's palette, and coupling
/// them would mean editing a shared file to add a component).
abstract final class TaxLotTokens {
  /// Light mode, as the `L1 · Light · 1024` artboard draws it.
  static const TaxLotPalette light = TaxLotPalette(
    surface: Color(0xFFFDFBFF),
    border: Color(0xFFEAE7F0),
    selectedSurface: Color(0xFFEEF0FF),
    selectedAccent: Color(0xFF4F5DFF),
    footerSurface: Color(0xFFF5F3FB),
    primaryText: Color(0xFF1A1B20),
    figureText: Color(0xFF44464E),
    labelText: Color(0xFF5F6169),
    mutedText: Color(0xFF8A8D96),
    gain: Color(0xFF12805C),
    loss: Color(0xFFC0362C),
    checkboxBorder: Color(0xFFC4C6D0),
    checkboxGlyph: Color(0xFFFFFFFF),
    placeholderBorder: Color(0xFFC4C6D0),
    shortTerm: TaxLotTermColors(
      accent: Color(0xFFF0A52E),
      chipForeground: Color(0xFF8A5A10),
      chipBackground: Color(0xFFFDF0DC),
      chipBorder: Color(0xFFF0D9A8),
    ),
    longTerm: TaxLotTermColors(
      accent: Color(0xFF0F9D8F),
      chipForeground: Color(0xFF0C6A60),
      chipBackground: Color(0xFFDCEFEC),
      chipBorder: Color(0xFFB8DDD6),
    ),
  );

  /// Dark mode, as the `D1 · Dark · 1024` artboard draws it.
  ///
  /// The geometry is pixel-identical between the artboards — only the
  /// palette changes — which is why one layout serves both. Note that
  /// [TaxLotPalette.mutedText] is the **same** `#8A8D96` in both: the
  /// designer holds the column headers at one value across themes.
  static const TaxLotPalette dark = TaxLotPalette(
    surface: Color(0xFF15161C),
    border: Color(0xFF24252D),
    selectedSurface: Color(0xFF20223A),
    selectedAccent: Color(0xFF7A83FF),
    footerSurface: Color(0xFF101017),
    primaryText: Color(0xFFE5E1E9),
    figureText: Color(0xFFC9CBD4),
    labelText: Color(0xFFA4A6B0),
    mutedText: Color(0xFF8A8D96),
    gain: Color(0xFF4ADE9E),
    loss: Color(0xFFFF6B5E),
    checkboxBorder: Color(0xFF45464F),
    checkboxGlyph: Color(0xFF0B0C10),
    placeholderBorder: Color(0xFF3A3B44),
    shortTerm: TaxLotTermColors(
      accent: Color(0xFFFFBF5C),
      chipForeground: Color(0xFFFFCF7A),
      chipBackground: Color(0xFF2E2410),
      chipBorder: Color(0xFF4A3A18),
    ),
    longTerm: TaxLotTermColors(
      accent: Color(0xFF3FC8B8),
      chipForeground: Color(0xFF6FE0D2),
      chipBackground: Color(0xFF12302C),
      chipBorder: Color(0xFF1F4A44),
    ),
  );

  /// The palette for [brightness].
  static TaxLotPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
