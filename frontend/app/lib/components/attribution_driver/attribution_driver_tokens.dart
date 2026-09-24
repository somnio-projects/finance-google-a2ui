import 'package:flutter/material.dart';

/// The drill-down card's own surfaces, **measured** from
/// `FlowA-Assistant.dc.html`'s D2 state — the one artboard that draws it,
/// and it is dark.
///
/// The light values are **inferred**, not measured (spec frontend/0014 OD-1):
/// the design exports no light D2. The card and its hairline take the Home
/// shell's card roles; the tile takes the neutral inset fill the waterfall's
/// own detail strip uses (`ChartPalette.rule`, light). Every text role —
/// text, muted, gain, loss, the ticker chip — is `HomeTokens`', whose dark
/// values the D2 state matches byte for byte (`#232036` / `#C9CBFF` for the
/// chip), and `attribution_driver_tokens_test.dart` pins those agreements.
///
/// A component's palette stays in the component's directory on purpose
/// (ADR-L D-3; `frontend/CLAUDE.md` § *Drawing a chart*).
@immutable
class AttributionDriverPalette {
  /// Creates a palette.
  const AttributionDriverPalette({
    required this.card,
    required this.border,
    required this.tile,
  });

  /// The card behind the whole detail.
  final Color card;

  /// The card's hairline.
  final Color border;

  /// The fill of each stat tile.
  final Color tile;
}

/// The two palettes, and the lookup the card uses.
abstract final class AttributionDriverTokens {
  /// Light: inferred from the Home shell's card roles and the chart's rule.
  static const AttributionDriverPalette light = AttributionDriverPalette(
    card: Color(0xFFFDFBFF),
    border: Color(0xFFEAE7F0),
    tile: Color(0xFFF0EEF5),
  );

  /// Dark: measured from Flow A's D2 state.
  static const AttributionDriverPalette dark = AttributionDriverPalette(
    card: Color(0xFF171826),
    border: Color(0xFF33354D),
    tile: Color(0xFF101017),
  );

  /// The palette for [brightness].
  static AttributionDriverPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette for the theme above [context].
  static AttributionDriverPalette of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
}
