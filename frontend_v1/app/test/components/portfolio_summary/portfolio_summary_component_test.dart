import 'package:finance_app/components/portfolio_summary/home_movers.dart';
import 'package:finance_app/components/portfolio_summary/home_range_selector.dart';
import 'package:finance_app/components/portfolio_summary/portfolio_summary_component.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// `portfolio.summary.v1` as a component (spec `frontend_v1/0001` AC-4):
/// Home's own hero and movers, bound to the same payload, with the range an
/// option the Assistant can edit through `renderView`.
void main() {
  const component = PortfolioSummaryComponent();
  final payload = ViewPayload.fromJson(
    CatalogSnapshot.load().exampleForView(component.viewId),
  );

  Future<void> pump(WidgetTester tester, {SurfaceEdits? scope}) {
    // The scope sits ABOVE the builder, so `build` reads it from its own
    // context — the way the surface host nests them.
    final card = Builder(
      builder: (context) => component.build(context, payload),
    );
    return tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: scope == null
              ? card
              : SurfaceEdits(
                  onOptionChanged: scope.onOptionChanged,
                  pendingOption: scope.pendingOption,
                  rejection: scope.rejection,
                  options: scope.options,
                  child: card,
                ),
        ),
      ),
      surfaceSize: const Size(800, 1400),
      reducedMotion: true,
    );
  }

  test('binds the frozen view id and the catalog name', () {
    expect(component.viewId, 'portfolio.summary.v1');
    expect(component.a2uiComponent, 'PortfolioSummary');
  });

  testWidgets('draws the hero and the movers from display strings', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(payload.text('total.amount.display')), findsOneWidget);
    expect(find.byType(HomeMovers), findsOneWidget);
    // Read-only: tapping a range does nothing anywhere.
    await tester.tap(find.text('1Y'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects the option range and sends an edit as the option', (
    tester,
  ) async {
    final edits = <(String, String)>[];
    await pump(
      tester,
      scope: SurfaceEdits(
        onOptionChanged: (option, value) => edits.add((option, value)),
        options: const <String, Object?>{'range': '1m'},
        child: const SizedBox(),
      ),
    );
    final selector = tester.widget<HomeRangeSelector>(
      find.byType(HomeRangeSelector),
    );
    expect(selector.selected, '1m');
    await tester.tap(find.text('1Y'));
    expect(edits.single, ('range', '1y'));
  });

  testWidgets('waits on a range in flight, and shows a refusal verbatim', (
    tester,
  ) async {
    await pump(
      tester,
      scope: SurfaceEdits(
        onOptionChanged: (_, _) {},
        pendingOption: 'range',
        rejection: "Option 'range' must be one of: 1d, 1w.",
        child: const SizedBox(),
      ),
    );
    expect(find.byType(SkeletonShimmer), findsWidgets);
    expect(find.text("Option 'range' must be one of: 1d, 1w."), findsOneWidget);
  });
}
