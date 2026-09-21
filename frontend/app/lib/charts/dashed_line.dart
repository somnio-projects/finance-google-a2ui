import 'package:flutter/material.dart';

/// Draws a horizontal dashed run from [from] to [to].
///
/// Split out of the painter to keep it inside the 150-line budget, and it
/// earns its own file anyway: every later chart with a reference line or a
/// projection wants the same stroke.
///
/// **The pattern is approximate, and knowingly so.** CSS leaves the dash
/// pattern of a `dashed` border to the user agent, so the design carries no
/// measurable one — 4 on, 3 off is what Chrome renders at 1.5 px on the
/// reference page. `specs/frontend/0002` records it as the one measurement
/// that could not be taken.
void drawDashedLine(
  Canvas canvas,
  Offset from,
  Offset to,
  Paint paint, {
  double dash = 4,
  double gap = 3,
}) {
  for (var x = from.dx; x < to.dx; x += dash + gap) {
    final end = x + dash < to.dx ? x + dash : to.dx;
    canvas.drawLine(Offset(x, from.dy), Offset(end, to.dy), paint);
  }
}
