import 'package:flutter/material.dart';

/// The waterfall card's own colours: the headline pill and the selection.
///
/// Measured from `Catalog_AttributionWaterfall.dc.html` (the pill, both
/// artboards) and `FlowA-Assistant.dc.html`'s D2 state (the dashed selection
/// outline and the *NVDA selected* caption, dark). The light selection is the
/// catalog page's own `ring` for the selected bar, `#4f5dff`. Every other role
/// the card needs — surfaces, marks, muted text — is `ChartPalette`'s, and
/// `attribution_waterfall_tokens_test.dart` pins the shared roles to it.
///
/// A component's palette stays in the component's directory on purpose:
/// registering a `ThemeExtension` would mean editing `AppTheme` to add one,
/// which ADR-L D-3 forbids (`frontend/CLAUDE.md` § *Drawing a chart*).
@immutable
class AttributionWaterfallPalette {
  /// Creates a palette.
  const AttributionWaterfallPalette({
    required this.pillGainSurface,
    required this.selection,
  });

  /// The fill behind a gain's headline pill.
  ///
  /// The design shows the pill only for a gain. A loss or a flat walk keeps
  /// the neutral chip fill (`ChartPalette.rule`) rather than a colour nobody
  /// measured — spec frontend/0014 OD-3.
  final Color pillGainSurface;

  /// The dashed outline of a selected bar, its axis label and the header's
  /// *selected* caption.
  final Color selection;
}

/// The two measured palettes, and the lookup the card uses.
abstract final class AttributionWaterfallTokens {
  /// Light: the catalog page's `L1 · Light · 1024` artboard.
  static const AttributionWaterfallPalette light = AttributionWaterfallPalette(
    pillGainSurface: Color(0xFFE3F3EC),
    selection: Color(0xFF4F5DFF),
  );

  /// Dark: the catalog page's pill and Flow A's D2 selection.
  static const AttributionWaterfallPalette dark = AttributionWaterfallPalette(
    pillGainSurface: Color(0xFF12291F),
    selection: Color(0xFFB9C0FF),
  );

  /// The palette for [brightness].
  static AttributionWaterfallPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette for the theme above [context].
  static AttributionWaterfallPalette of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
}
