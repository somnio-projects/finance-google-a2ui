import 'package:finance_app/components/holdings_allocation/holdings_summary_tokens.dart';
import 'package:flutter/material.dart';

/// The grouping toggle's measured palette and geometry (GGU-145).
///
/// **Read from Miriam's Figma, not from a mock.** Every value below was taken
/// through the inspector from the `HoldingsSummary` section of
/// `figma.com/design/rFA8ZEEOOvnOyq7IrTObma/A2UI-FINANCE-UI-KIT`, on the
/// `Default, Light, Desktop` and `Default, Dark, Mobile` variants. The design
/// names them as tokens — `surface/tertiary`, `surface/primary`,
/// `border/primary`, `text/primary`, `text/secondary` — and those names are
/// kept in the comments so a future reader can find the same swatch.
///
/// The provenance line is here because it was wrong elsewhere:
/// `.design-refs/*.dc.html` was cited as "the design" across several specs and
/// it is **our own mock**, generated on this side and handed to the designer as
/// a starting point (Miriam, 2026-09-28). Figma is the authority.
@immutable
class AllocationToggleTokens {
  /// Creates a palette. Only [selectedBorder] is optional, because only the
  /// dark artboard draws one.
  const AllocationToggleTokens({
    required this.track,
    required this.selectedSurface,
    required this.selectedText,
    required this.text,
    this.selectedBorder,
  });

  /// Light mode, as `Default, Light, Desktop` draws it.
  ///
  /// The selected segment has no `Bordes` entry there — it is separated from
  /// the track by contrast alone, which is why [selectedBorder] is null.
  static const AllocationToggleTokens light = AllocationToggleTokens(
    // surface/tertiary
    track: Color(0xFFF6F6F7),
    // surface/primary
    selectedSurface: Color(0xFFFFFFFF),
    selectedText: HoldingsSummaryText.lightPrimary,
    text: HoldingsSummaryText.lightSecondary,
  );

  /// Dark mode, as `Default, Dark, Mobile` draws it.
  ///
  /// Here the selected segment is *darker* than the track, so the design adds
  /// a hairline to keep its edge readable.
  static const AllocationToggleTokens dark = AllocationToggleTokens(
    // surface/tertiary
    track: Color(0xFF26292F),
    // surface/primary
    selectedSurface: Color(0xFF17181C),
    // border/primary, 1px on all sides
    selectedBorder: Color(0xFF353A42),
    selectedText: HoldingsSummaryText.darkPrimary,
    text: HoldingsSummaryText.darkSecondary,
  );

  /// The control's outer height (`Altura Ajustado 32px`).
  static const double trackHeight = 32;

  /// The padding between the track and a segment (`spacing/4`).
  static const double trackPadding = 4;

  /// The gap between two segments (`Espacio spacing/2`).
  static const double segmentGap = 2;

  /// A segment's height (`Altura Ajustado 24px`).
  static const double segmentHeight = 24;

  /// A segment's vertical padding (`spacing/4`).
  static const double segmentPaddingY = 4;

  /// A segment's horizontal padding (`spacing/12`).
  static const double segmentPaddingX = 12;

  /// The label's size (`font-size/12`).
  static const double labelSize = 12;

  /// The label's weight (`Peso 500`, `Estilo Medium`).
  static const FontWeight labelWeight = FontWeight.w500;

  /// The label's line height (`Altura de la línea 100%`).
  static const double labelHeight = 1;

  /// The track and each segment are pills (`radius/full`).
  static const double radius = 999;

  /// The control's own fill.
  final Color track;

  /// The fill behind the segment in force.
  final Color selectedSurface;

  /// The hairline around that segment, or null where the design draws none.
  final Color? selectedBorder;

  /// That segment's label — `text/primary`, the card's own.
  final Color selectedText;

  /// Every other segment's label — `text/secondary`.
  final Color text;

  /// The palette matching [context]'s theme brightness.
  static AllocationToggleTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
