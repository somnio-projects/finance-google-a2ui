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
///
/// Read off Miriam's Figma `HoldingsSummary` artboard (GGU-145). It was 150
/// until 2026-09-28, from the catalog mock this repository generated.
const double designOuterDiameter = 160;

/// The primary card's hole diameter, in logical pixels, as rendered.
///
/// See [designOuterDiameter]; it was 92, which is a ring more than twice as
/// thick as the design draws and too small to hold the design's own total.
const double designHoleDiameter = 135;

/// The two secondary cards' ring and hole diameters.
///
/// The by-sector and loading cards are both 112/68. The `Holdings` screen
/// draws the same component at 96/60. Three ratios — 0.613, 0.607, 0.625 —
/// which is a design consistent to about ±1.5 %, not a single constant.
const double designSecondaryOuterDiameter = 112;

/// See [designSecondaryOuterDiameter].
const double designSecondaryHoleDiameter = 68;

/// The catalog example's five shares, as the backend sends them (fractions).
///
/// From `docs/catalog/view-catalog.snapshot.json`, `holdings.allocation.v1`.
/// Unlike the design's tidy percentages, **none of its boundaries lands on an
/// axis or a diagonal** — which is exactly why the hit test is exercised
/// against this payload and not only against four equal quarters.
const List<double> catalogExampleWeights = <double>[
  0.5927249356535964,
  0.2445086456350536,
  0.0937289548053002,
  0.0455498734597608,
  0.0234875904462888,
];

/// `(dx, dy, expected slice)`, 1.5° either side of each boundary of
/// [catalogExampleWeights] at the design's 75 px radius.
///
/// A record rather than a `List<double>`, so the slice index stays an `int`:
/// reading it out of a list of doubles needed a narrowing conversion at the
/// call site, which `binding_rules_compute_test.dart` bans — correctly, and it
/// caught that too. (It greps source text, so the mechanism is described here
/// rather than spelled, which is the second time this change learned that.)
///
/// Computed **independently** of the code under test, with `dart:math`'s own
/// `atan2` in a scratch script, for the reason [designClassStops] exists: a
/// reference value the implementation cannot have produced is the only kind
/// that can contradict it. 1.5° sits well inside the 4.075° error of the
/// approximation this replaced, so these values fail on that implementation
/// and pass on the current one.
const List<(double dx, double dy, int slice)> referenceTaps =
    <(double, double, int)>[
      (-39.611732, 63.686032, 0),
      (-42.890515, 61.525634, 1),
      (-65.014588, -37.391221, 1),
      (-62.968582, -40.742578, 2),
      (-33.293092, -67.205432, 2),
      (-29.730204, -68.855755, 3),
      (-12.966286, -73.870667, 3),
      (-9.082424, -74.448033, 4),
      (-1.963271, -74.974299, 4),
      (1.963271, -74.974299, 0),
    ];
