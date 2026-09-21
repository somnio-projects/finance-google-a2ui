/// Framework-free chart primitives.
///
/// The geometry half of every chart this client draws: scales, readable tick
/// steps, and layouts that turn a list of values into rectangles and points.
/// It imports no Flutter and paints nothing, which is what lets the geometry
/// be asserted under `dart test` in about a second (ADR-L D-13). The painter
/// that consumes it lives in `app/lib/charts/`, because a `CustomPainter`
/// needs `dart:ui` and `packages/` may not have it.
library;

export 'src/band_scale.dart';
export 'src/chart_geometry.dart';
export 'src/donut_hit_test.dart';
export 'src/donut_layout.dart';
export 'src/linear_scale.dart';
export 'src/tick_steps.dart';
export 'src/waterfall_layout.dart';
export 'src/waterfall_step.dart';
