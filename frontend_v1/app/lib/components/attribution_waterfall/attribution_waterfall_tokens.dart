import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The waterfall card's own colours: the selection and the detail surfaces.
///
/// Measured from the UI Kit's *Waterfall* frame (spec frontend/0028 §2).
/// Every other role the card needs — surfaces, marks, muted text — is
/// `ChartPalette`'s, and `attribution_waterfall_tokens_test.dart` pins the
/// shared ones to it so the two files cannot drift while staying separate.
///
/// **The selected fills are derived, not transcribed, and the reason is in
/// the measurement.** The UI Kit draws the walk on a lighter base than the one
/// this app measured off the component catalog page — its resting gain is
/// `#2FA584` against our `#12805C` — so its *selected* gain, `#1D7059`, is
/// **lighter** than the bar we would be deepening. Copying it would make a
/// tapped bar recede. These keep the UI Kit's direction and contrast instead
/// (deeper in light, brighter in dark), applied to this app's own marks, and
/// the test asserts that direction rather than the hex, so the rule survives
/// the next palette change (0028 OD-3).
///
/// A component's palette stays in the component's directory on purpose:
/// registering a `ThemeExtension` would mean editing `AppTheme` to add one,
/// which ADR-L D-3 forbids (`frontend/CLAUDE.md` § *Drawing a chart*).
@immutable
class AttributionWaterfallPalette {
  /// Creates a palette.
  const AttributionWaterfallPalette({
    required this.selectedGainBar,
    required this.selectedLossBar,
    required this.gainColumn,
    required this.lossColumn,
    required this.footerSurface,
    required this.calloutShadow,
  });

  /// The fill a selected `direction: up` bar takes.
  final Color selectedGainBar;

  /// The fill a selected `direction: down` bar takes.
  final Color selectedLossBar;

  /// The tint behind a selected gain's whole band.
  final Color gainColumn;

  /// The tint behind a selected loss's whole band.
  ///
  /// **Light is measured; dark is derived.** The UI Kit exports a selected
  /// loss only on the light artboard, so the dark value is the gain tint's
  /// recipe applied to the loss hue and is flagged for design in 0028 §6.
  final Color lossColumn;

  /// The strip under the chart that carries the selected bucket's detail on
  /// a card too narrow for the callout.
  final Color footerSurface;

  /// The shadow under the desktop callout, which is what lifts it off the
  /// plot it covers.
  final Color calloutShadow;

  /// The fill for a bar of [kind] while it is the selected one.
  ///
  /// A total is never selectable — neither endpoint has a `key` to drill
  /// into — so its fill is its own mark and the card never asks for this.
  Color selectedBarFor(WaterfallStepKind kind) =>
      kind == WaterfallStepKind.loss ? selectedLossBar : selectedGainBar;

  /// The column tint for a bar of [kind]. See [selectedBarFor].
  Color columnFor(WaterfallStepKind kind) =>
      kind == WaterfallStepKind.loss ? lossColumn : gainColumn;
}

/// The two measured palettes, and the lookup the card uses.
abstract final class AttributionWaterfallTokens {
  /// Light, from the UI Kit's `Light · mobile` and `Light · desktop` cards.
  static const AttributionWaterfallPalette light = AttributionWaterfallPalette(
    selectedGainBar: Color(0xFF0C6349),
    selectedLossBar: Color(0xFF8E2A22),
    gainColumn: Color(0xFFE8FEF3),
    lossColumn: Color(0xFFFFEDEB),
    footerSurface: Color(0xFFF5F3FB),
    calloutShadow: Color(0x1A000000),
  );

  /// Dark, from the same frame's two dark cards.
  static const AttributionWaterfallPalette dark = AttributionWaterfallPalette(
    selectedGainBar: Color(0xFF7BEFC0),
    selectedLossBar: Color(0xFFFF9B90),
    gainColumn: Color(0xFF132520),
    lossColumn: Color(0xFF2A1513),
    footerSurface: Color(0xFF1C1D25),
    calloutShadow: Color(0x73000000),
  );

  /// The palette for [brightness].
  static AttributionWaterfallPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette for the theme above [context].
  static AttributionWaterfallPalette of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
}
