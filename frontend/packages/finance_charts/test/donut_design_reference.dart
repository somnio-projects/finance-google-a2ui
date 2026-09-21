/// The donut on the designer's catalog page, and what it measures.
///
/// Extracted from `.design-refs/Catalog_HoldingsSummary.dc.html` by serving
/// the page over HTTP and reading `getComputedStyle(...).backgroundImage` off
/// the rendered node — **not** from a `file://` render, which the preview tool
/// rewrites to a `data:` URL so that the page's `./support.js` never resolves
/// and every binding stays an unexpanded `{{ … }}`. A measurement taken there
/// would be a measurement of placeholders. `specs/frontend/0007` §1c records
/// the method and why it matters.
///
/// The design draws the ring as a CSS `conic-gradient(from 0deg, …)`, whose
/// zero is twelve o'clock and which sweeps clockwise. Each stop is therefore
/// directly comparable with a `DonutArc` once converted, which is what
/// `donut_layout_test.dart` does.
library;

/// The by-asset-class donut's weights, as the design's own percentages.
///
/// From the page's `renderVals()`: `{Equities 62, Bonds 18, Cash 8,
/// Alternatives 12}`. They are percentages here because the design's are;
/// the backend sends the same quantity as a fraction, and `DonutLayout`
/// normalises by the sum either way.
const List<double> designClassWeights = <double>[62, 18, 8, 12];

/// Where each by-class slice **ends**, in CSS degrees from twelve o'clock.
///
/// Read from the rendered `conic-gradient`, verbatim:
/// `rgb(79,93,255) 0deg … 223.2deg, rgb(12,157,143) 223.2deg … 288deg,
/// rgb(217,144,0) 288deg … 316.8deg, rgb(154,92,255) 316.8deg … 360deg`.
const List<double> designClassStops = <double>[223.2, 288, 316.8, 360];

/// The by-sector donut's weights, from the same `renderVals()`.
const List<double> designSectorWeights = <double>[34, 16, 13, 12, 9, 16];

/// Where each by-sector slice ends, in CSS degrees, as rendered.
const List<double> designSectorStops = <double>[
  122.4,
  180,
  226.8,
  270,
  302.4,
  360,
];

/// The primary card's ring diameter, in logical pixels, as rendered.
const double designOuterDiameter = 150;

/// The primary card's hole diameter, in logical pixels, as rendered.
const double designHoleDiameter = 92;

/// The two secondary cards' ring and hole diameters.
///
/// The by-sector and loading cards are both 112/68. The `Holdings` screen
/// draws the same component at 96/60. Three ratios — 0.613, 0.607, 0.625 —
/// which is a design consistent to about ±1.5 %, not a single constant.
const double designSecondaryOuterDiameter = 112;

/// See [designSecondaryOuterDiameter].
const double designSecondaryHoleDiameter = 68;
