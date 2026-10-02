import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:flutter/material.dart';

/// Gives the metric grid the width the design measured it at, and scrolls it
/// sideways when the surface is narrower than that (GGU-144).
///
/// **The problem this solves, stated precisely.** The design draws this card
/// at 571.367 points on a 1024 artboard; the app is a 390-point phone and
/// `AppShell` keeps that column at 430 even on a desktop, deliberately —
/// *"a stretched card is not the same design at a different size, it is a
/// different design"* — a ruling that lives in `app_shell.dart`'s own doc
/// comment and in no spec, which `specs/frontend/0032` OD-1 records.
///
/// So the grid is asked to lay four tracks out in 392 points where the
/// design gave it 533, and it cannot: measured in the running client at
/// `local+a31149c`, every figure cell wrapped mid-number, `$20,000.` over
/// `00`.
///
/// **Why scrolling and not the alternatives.** Three other answers were
/// considered and each gives something up that this one does not:
///
/// * *Widen the shell on a wide viewport* — contradicts `AppShell`'s own
///   ruling, which has reasoning behind it and is not an oversight.
///   Overturning it is a decision about the whole app, not a fix for one
///   card.
/// * *Scale the table down to fit* (`FittedBox`) — preserves every measured
///   proportion exactly, and defeats dynamic type: the figures would stop
///   responding to the system font size, which
///   `.claude/rules/flutter/best-practices.md` requires them to. An
///   accessibility regression is a worse trade than a scroll.
/// * *Ask the backend for fewer columns on a narrow client* — the client
///   deciding what to compare, which is a product decision and N-10's
///   neighbourhood. If it is ever right it is a design call, not a layout
///   one.
///
/// Scrolling keeps every figure whole, keeps the measured type scale, and
/// keeps dynamic type working. What it costs is that the third column needs
/// a sideways drag on a phone — the ordinary price of a wide table on a
/// narrow screen, and the winner's tick travels with its own cell, so *which
/// column won this row* is still answered wherever you have scrolled to.
///
/// **What is deliberately not done, and what it would take.** The metric
/// names scroll away with everything else, so at the far right a reader sees
/// three columns of figures and no row labels. Pinning that first track is
/// the better answer and it is not free: two scroll views that stay in step
/// need linked controllers (a dependency) or fixed row heights (a measured
/// value the design does not give at this width), and each row's height is
/// currently set by the metric cell, which is two lines against the value
/// cell's one. Left as a known improvement rather than guessed at.
///
/// At or above [ScenarioComparisonLayout.minGridWidth] nothing scrolls and
/// the grid is laid out exactly as it is today, which is why the geometry
/// suite and both goldens are untouched by this.
class ScenarioGridViewport extends StatelessWidget {
  /// Wraps [child] — the metric grid — in its own horizontal viewport.
  const ScenarioGridViewport({required this.child, super.key});

  /// The grid: the column headers and every metric row.
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // A comparison, not arithmetic: `dart:math` is one of the twelve
      // mechanisms `binding_rules_test.dart` fails `lib/` on, and reaching
      // for `max` here would trip it for a layout decision that has nothing
      // to do with a payload figure.
      child: SizedBox(
        width: constraints.maxWidth < ScenarioComparisonLayout.minGridWidth
            ? ScenarioComparisonLayout.minGridWidth
            : constraints.maxWidth,
        child: child,
      ),
    ),
  );
}
