import 'package:finance_app/components/scenario_comparison/scenario_comparison_card.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_track_row.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'scenario_comparison_harness.dart';

/// GGU-144 — the grid keeps the design's width and scrolls, rather than
/// squeezing its tracks to fit the shell.
///
/// The defect these are written against was found in the running client and
/// not by the suite, because every existing test pumps this card at
/// `designCardWidth` — exactly the width at which nothing is wrong. A suite
/// that only ever asks the question at the design's own size cannot see a
/// layout that fails at two thirds of it.
///
/// **What is asserted here is geometry, not typography**, and that is the
/// split `.claude/rules/frontend/testing.md` §6 prescribes rather than a
/// convenience. The first draft asserted the symptom directly — *no figure
/// is broken across two lines* — and it failed at the design's own width,
/// because `flutter test` renders every glyph in the test font as a full em
/// square: `+$7,062.50` "needs" 135 points there, against a track the
/// designer sized at 121. That assertion was measuring the test font. The
/// honest check is that each track is the width the design gave it.
void main() {
  group(ScenarioGridViewport, () {
    /// The card at [width], which is how the Assistant shows it: a phone
    /// column, not the 1024 artboard.
    Future<void> pumpAt(WidgetTester tester, double width) => tester.pumpApp(
      Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: ScenarioComparisonCard(data: scenarioData()),
          ),
        ),
      ),
    );

    /// The grid's own width — the header row, which spans every track.
    double gridWidth(WidgetTester tester) =>
        tester.getSize(find.byType(ScenarioTrackRow).first).width;

    /// The scrollable the viewport installs.
    ScrollPosition scroller(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ScenarioGridViewport),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    test('the minimum is the width the design draws the card at', () {
      // The one assertion keeping two declarations of one design fact
      // together: `minGridWidth` in `lib/`, and the harness's
      // `designContentWidth`, read from the DOM. They are allowed to be the
      // same number; they are not allowed to drift.
      expect(ScenarioComparisonLayout.minGridWidth, designContentWidth);
    });

    testWidgets('keeps the design width when the shell is narrower', (
      tester,
    ) async {
      // 430 is `AppShell.maxWidth` — the widest the app's column ever gets,
      // on a phone or on a desktop. Written as a
      // number rather than imported, because a component may not reach into
      // a feature.
      await pumpAt(tester, 430);

      expect(gridWidth(tester), closeTo(designContentWidth, 0.01));
    });

    testWidgets('gives every track the width the design measured', (
      tester,
    ) async {
      // The defect, expressed as its cause: at 430 the card's content box is
      // 392, and four tracks laid out in 392 are each about a quarter
      // narrower than the designer drew them — which is what broke the
      // figures. These are the same numbers the geometry suite asserts at
      // the artboard; the point is that they no longer depend on the surface
      // being the artboard.
      await pumpAt(tester, 430);
      final row = tester.renderObject<RenderFlex>(
        find
            .descendant(
              of: find.byType(ScenarioTrackRow).first,
              matching: find.byType(Row),
            )
            .first,
      );

      expect(
        row.getChildrenAsList().map((child) => child.size.width).toList(),
        <Matcher>[
          closeTo(145.531, 0.1),
          closeTo(8, 0.001),
          closeTo(121.273, 0.1),
          closeTo(8, 0.001),
          closeTo(121.281, 0.1),
          closeTo(8, 0.001),
          closeTo(121.281, 0.1),
        ],
      );
    });

    testWidgets('scrolls sideways so the last column can be reached', (
      tester,
    ) async {
      await pumpAt(tester, 430);

      expect(scroller(tester).axis, Axis.horizontal);
      expect(scroller(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('does not scroll at the design width', (tester) async {
      // The other half, and the reason the geometry suite and both goldens
      // are untouched by this change: at or above the minimum the grid fills
      // its surface and there is nowhere to scroll to.
      await pumpScenarioCard(tester, scenarioData());

      expect(scroller(tester).maxScrollExtent, 0);
    });

    testWidgets('fills a surface wider than the design draws', (tester) async {
      // The catalog board is 1024. The grid grows into the room it is given
      // rather than sitting at 533 with a gap beside it.
      await pumpAt(tester, 800);

      expect(gridWidth(tester), greaterThan(designContentWidth));
      expect(scroller(tester).maxScrollExtent, 0);
    });
  });
}
