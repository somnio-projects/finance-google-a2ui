import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:flutter/material.dart';

/// The chart palette in each brightness, **measured from the design**.
///
/// Every value below was read out of the designer's catalog page by
/// inspecting the rendered DOM (`getComputedStyle`) rather than taken from a
/// hand-written token list — two of the five values circulated informally
/// were wrong: the dark surface is `#15161C`, not `#14151A`, and the dark
/// neutral bar is `#6F7280`, not `#4B4D57`. `specs/frontend/0002` records the
/// full table and how it was obtained.
///
/// A widget reads [ChartPalette.of] rather than a literal. This file used to
/// claim it was *the only* file in `app/lib/` naming a `Color`; it never was
/// for long, because ADR-L D-3 makes every design-bound surface bring its own
/// token file rather than edit this one. The rule that survives is the
/// checkable one — a colour literal lives in a `*_tokens.dart` or a
/// `*_palettes.dart` and nowhere else, asserted by
/// `app/test/architecture/color_rules_test.dart` (spec frontend/0029 OD-4).
abstract final class ChartTokens {
  /// Light mode, as the `L1 · Light · 1024` artboard draws it.
  static const ChartPalette light = ChartPalette(
    surface: Color(0xFFFDFBFF),
    border: Color(0xFFEAE7F0),
    title: Color(0xFF1A1B20),
    barNeutral: Color(0xFF8A8D96),
    barGain: Color(0xFF12805C),
    barLoss: Color(0xFFC0362C),
    barTotal: Color(0xFF4F5DFF),
    connector: Color(0xFFC4C6D0),
    rule: Color(0xFFF0EEF5),
    mutedLabel: Color(0xFF5F6169),
  );

  /// Dark mode, as the `D1 · Dark · 1024` artboard draws it.
  ///
  /// The geometry is pixel-identical between the two artboards — only the
  /// palette changes — which is why one layout serves both.
  static const ChartPalette dark = ChartPalette(
    surface: Color(0xFF15161C),
    border: Color(0xFF24252D),
    title: Color(0xFFE5E1E9),
    barNeutral: Color(0xFF6F7280),
    barGain: Color(0xFF4ADE9E),
    barLoss: Color(0xFFFF6B5E),
    barTotal: Color(0xFF7A83FF),
    connector: Color(0xFF3A3B44),
    rule: Color(0xFF24252D),
    mutedLabel: Color(0xFFA4A6B0),
  );

  /// The palette for [brightness].
  static ChartPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The allocation ramp and legend colours, light, as the catalog page's
  /// `L1 · Light · 1024` artboard renders them.
  ///
  /// The six hues are the design's `palSecL`, read from the page's own
  /// `renderVals()` and confirmed against the rendered `conic-gradient`. Its
  /// four-category state (`palClsL`) is the first four of these, so one ramp
  /// serves both. The first hue is `#4f5dff`, which is also
  /// [ChartPalette.barTotal] — the two charts share an accent on purpose.
  ///
  /// **The `Holdings` screen disagrees**, drawing the same component with
  /// `#0f9d8f, #9aa0aa, #f0a52e` in slots 2–4. The component page is the
  /// contract, so these are its values; `specs/frontend/0007` OD-2 carries the
  /// divergence for design to settle.
  static const AllocationPalette allocationLight = AllocationPalette(
    swatches: <Color>[
      Color(0xFF4F5DFF),
      Color(0xFF0C9D8F),
      Color(0xFFD99000),
      Color(0xFF9A5CFF),
      Color(0xFFE0607A),
      Color(0xFF7A8090),
    ],
    legendWeight: Color(0xFF8A8D96),
    legendValue: Color(0xFF44464E),
    legendDivider: Color(0xFFF2EFF7),
    classSwatches: <Color>[
      Color(0xFF4F5DFF),
      Color(0xFF0F9D8F),
      Color(0xFF9AA0AA),
      Color(0xFFF0A52E),
    ],
  );

  /// The allocation ramp and legend colours, dark (`D1 · Dark · 1024`).
  ///
  /// The geometry is identical between the two artboards; only the palette
  /// changes. Note `legendWeight` is `#8A8D96` in **both** themes — the design
  /// does not lighten it for dark, which is why it is written twice here
  /// rather than derived.
  static const AllocationPalette allocationDark = AllocationPalette(
    swatches: <Color>[
      Color(0xFF7A83FF),
      Color(0xFF2DD4BF),
      Color(0xFFF5B942),
      Color(0xFFC08CFF),
      Color(0xFFFF8FA3),
      Color(0xFFA4A6B0),
    ],
    legendWeight: Color(0xFF8A8D96),
    legendValue: Color(0xFFC9CBD4),
    legendDivider: Color(0xFF23242C),
    classSwatches: <Color>[
      Color(0xFF7A83FF),
      Color(0xFF3FC8B8),
      Color(0xFF6F7280),
      Color(0xFFF5B942),
    ],
  );

  /// The allocation palette for [brightness].
  static AllocationPalette allocationFor(Brightness brightness) =>
      brightness == Brightness.dark ? allocationDark : allocationLight;
}
