import 'package:finance_app/charts/payoff_palette.dart';
import 'package:flutter/material.dart';

/// The payoff curve's palette, **measured from Miriam's Figma** (GGU-146).
///
/// Read through the inspector from `Risk Payoff Chart / Comparison, Light,
/// Desktop` and its dark twin, node by node. The kit's own token names are
/// kept in the comments so a future reader can find the same swatch.
///
/// **Everything here was wrong before, and wrong in the same way.** The old
/// values came from `.design-refs/Catalog_RiskPayoffChart.dc.html` — the
/// catalog mock this repository generated and handed to the designer, which
/// GGU-145 established is not a design export. Measuring our own output and
/// calling it "measured from the design" is a loop that cannot disagree with
/// itself, and this file is what it produced:
///
/// | role | mock | design |
/// |---|---|---|
/// | region wash | `barGain`/`barLoss` at **7 %** / 10 % | its own token at **80 %** |
/// | break-even | amber `#C07A10` | grey `border/secondary` |
/// | axis label | `#9A9BA4` | `text/secondary` |
///
/// The washes are the sharpest: an alpha an order of magnitude off, derived
/// from a colour the design does not use for this at all.
abstract final class PayoffTokens {
  /// The opacity the artboard draws both region washes at.
  ///
  /// One number for both themes, unlike the mock's two — the kit changes the
  /// *token* between themes and leaves the opacity alone.
  static const double wash = 0.8;

  /// Light mode, as `Comparison, Light, Desktop` draws it.
  static final PayoffPalette light = PayoffPalette(
    // border/secondary — a plain grey rule, 1.5 px, dashed 5 / 4.
    breakEven: const Color(0xFFCBCDD0),
    zeroBaseline: const Color(0xFFB8BCC6),
    // text/secondary — the same role the rung labels, the region words and
    // the break-even's caption all take.
    axisLabel: const Color(0xFF56575B),
    // negative/surface
    lossRegion: const Color(0xFFFFEDEB).withValues(alpha: wash),
    // positive/surface
    gainRegion: const Color(0xFFD8FDEB).withValues(alpha: wash),
    // border/principal
    series: const Color(0xFF5498E5),
    // No token in the kit — see `PayoffPalette.seriesAlt`.
    seriesAlt: const Color(0xFF5F6169),
    // action/principal/default
    marker: const Color(0xFF3C90F1),
    // surface/primary
    markerHalo: const Color(0xFFFFFFFF),
  );

  /// Dark mode, as `Comparison, Dark, Desktop` draws it.
  static final PayoffPalette dark = PayoffPalette(
    // border/secondary
    breakEven: const Color(0xFF474D58),
    zeroBaseline: const Color(0xFF3A3B44),
    // text/secondary
    axisLabel: const Color(0xFFB9BEC6),
    // surface/negative
    lossRegion: const Color(0xFF3F1D1D).withValues(alpha: wash),
    // surface/positive
    gainRegion: const Color(0xFF132520).withValues(alpha: wash),
    // border/principal
    series: const Color(0xFF1763BA),
    // The same raw hex as light: the kit binds this one to nothing.
    seriesAlt: const Color(0xFF5F6169),
    // action/principal/default
    marker: const Color(0xFF308CF5),
    // surface/primary
    markerHalo: const Color(0xFF17181C),
  );

  /// The palette for [brightness].
  static PayoffPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
