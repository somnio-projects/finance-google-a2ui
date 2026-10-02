/// The payoff chart as the design draws it, for the geometry suite.
///
/// Taken from `.design-refs/Catalog_RiskPayoffChart.dc.html` — specifically
/// its own `<script type="text/x-dc">` block, which carries the artboard's
/// scales **as arithmetic** rather than as a rendered picture:
///
/// ```js
/// scaleX(x) { return 44 + (x + 30) / 60 * (486 - 44); }
/// scaleY(y) { return 244 - (y + 4000) / 24000 * (244 - 18); }
/// ```
///
/// Reading the source rather than the DOM matters here: served from `file://`
/// the page's bundle never boots, so the curve is never drawn and a screen
/// measurement would be of an empty plot. These numbers were additionally
/// confirmed against an HTTP render, where the curve does draw and the
/// break-even rule lands 26.5 % across the plot — the 26.67 % these scales
/// predict (`specs/frontend/0005` §4).
library;

import 'package:finance_charts/finance_charts.dart';

/// The design's plot width: `x` runs 44 → 486 inside a 500-wide viewBox.
const double designPlotWidth = 486 - 44;

/// The design's plot height: `y` runs 18 → 244 inside a 280-tall viewBox.
const double designPlotHeight = 244 - 18;

/// The artboard's `scaleX`, rebased so the plot's left edge is `x = 0`.
///
/// The design's own function offsets by the 44 px gutter it keeps for value
/// labels. This client draws no value labels — they would have to be
/// formatted here, which N-1 forbids — so its plot starts at zero and the
/// gutter is absent. Subtracting it is the whole of the difference.
double designScaleX(double at) => 44 + (at + 30) / 60 * designPlotWidth - 44;

/// The `hold` curve the artboard plots: a position with protective puts,
/// floored at −$2,400 until the strike and linear above it.
///
/// Kept verbatim although this client binds a **linear spot** payoff, because
/// it is the shape most likely to catch a layout that assumed monotonicity or
/// evenly spaced samples. `specs/frontend/0005` OD-3 records that the design
/// and the backend describe different products.
const List<PayoffPoint> designCurve = <PayoffPoint>[
  PayoffPoint(at: -30, value: -2400),
  PayoffPoint(at: -24, value: -2400),
  PayoffPoint(at: -20, value: -2400),
  PayoffPoint(at: -18, value: -1680),
  PayoffPoint(at: -14, value: 0),
  PayoffPoint(at: -8, value: 2520),
  PayoffPoint(at: 0, value: 5880),
  PayoffPoint(at: 10, value: 10080),
  PayoffPoint(at: 20, value: 14280),
  PayoffPoint(at: 30, value: 18480),
];
