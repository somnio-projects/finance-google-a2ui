import 'package:finance_charts/finance_charts.dart';

/// The waterfall on the designer's catalog page, and what it measures.
///
/// Extracted from `Catalog - Attribution Waterfall.html` by reading the
/// rendered DOM — `getBoundingClientRect` on every bar and connector — not by
/// eye and not from the design's own annotations. Keeping it in one file lets
/// the layout suite assert *the design* rather than assert itself.
///
/// The plot is 533.37 × 200 px. The browser reports positions to one decimal,
/// so comparisons against [designBarTops] use a 0.1 px tolerance.
const double designPlotWidth = 533.37;

/// The height of the reference plot, in logical pixels.
const double designPlotHeight = 200;

/// The seven steps of the reference walk, as running totals.
///
/// Note that the designer's simulated data does **not** close: the last
/// contribution leaves the walk at 482,815 while the closing total is
/// 482,915. That is a property of the mock, not of the backend — a backend
/// test asserts `attribution.waterfall.v1` closes arithmetically. The layout
/// is indifferent either way, which is itself worth pinning down.
const List<WaterfallStep> designSteps = <WaterfallStep>[
  WaterfallStep(key: 'start', kind: WaterfallStepKind.start, level: 479675),
  WaterfallStep(key: 'NVDA', kind: WaterfallStepKind.gain, level: 482655),
  WaterfallStep(key: 'MSFT', kind: WaterfallStepKind.gain, level: 483265),
  WaterfallStep(key: 'VOO', kind: WaterfallStepKind.gain, level: 483685),
  WaterfallStep(key: 'PYPL', kind: WaterfallStepKind.loss, level: 483145),
  WaterfallStep(key: 'FX', kind: WaterfallStepKind.loss, level: 482815),
  WaterfallStep(key: 'end', kind: WaterfallStepKind.total, level: 482915),
];

/// The top edge of each bar, in plot coordinates, as the design draws it.
const List<double> designBarTops = <double>[
  144.2,
  44.9,
  24.5,
  10.5,
  10.5,
  28.5,
  36.2,
];

/// The height of each bar, as the design draws it.
const List<double> designBarHeights = <double>[
  55.8,
  99.3,
  20.3,
  14,
  18,
  11,
  163.8,
];
