/// Every surface this app draws a header on, pumped at phone size with
/// enough content under the header to scroll (spec frontend/0024).
///
/// This half holds the shared vocabulary and the three tabs, which are
/// driven through their real page over a stubbed repository. The Assistant
/// and the two catalog pages are driven from a stubbed bloc instead and live
/// in `header_scroll_blocs.dart` — split by that difference, and because
/// one file would be over the 150-line budget.
library;

import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/features/conversation/view/assistant_header.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/home/bloc/home_bloc.dart';
import 'package:finance_app/features/home/view/home_header.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/tab_fixtures.dart';
import 'header_scroll_blocs.dart';

/// The phone the design is drawn for, and the one the TL was scrolling.
const Size phone = Size(375, 812);

/// A stand-in for the repository the three tabs read.
class MockViewsRepository extends Mock implements ViewsRepository;

/// One surface under test: its name, how to pump it, and its header.
typedef HeaderSurface = ({
  String name,
  Future<void> Function(WidgetTester tester) pump,
  Finder header,
});

/// Every surface the TL's *"de todas las paginas"* covers.
List<HeaderSurface> headerSurfaces() => <HeaderSurface>[
  (name: 'Home', pump: pumpHome, header: find.byType(HomeHeader)),
  (name: 'Holdings', pump: pumpHoldings, header: find.byType(TabAppBar)),
  (name: 'Activity', pump: pumpActivity, header: find.byType(TabAppBar)),
  (
    name: 'the Assistant',
    pump: pumpAssistant,
    header: find.byType(AssistantHeader),
  ),
  (
    name: 'the catalog index',
    pump: pumpCatalogIndex,
    header: find.byType(CatalogTopBar),
  ),
  (
    name: 'a catalog detail page',
    pump: pumpCatalogDetail,
    header: find.byType(CatalogTopBar),
  ),
];

/// Pumps the Home tab with both of its views answered.
Future<void> pumpHome(WidgetTester tester) async {
  final repository = MockViewsRepository();
  stubView(repository, HomeBloc.summaryView, 'PortfolioSummary');
  stubView(repository, HomeBloc.allocationView, 'HoldingsSummary');
  await tester.pumpApp(
    const HomePage(),
    viewsRepository: repository,
    componentRegistry: buildComponentRegistry(),
    surfaceSize: phone,
  );
  await tester.pumpAndSettle();
}

/// Pumps the Holdings tab with its positions and allocation answered.
Future<void> pumpHoldings(WidgetTester tester) async {
  final repository = MockViewsRepository();
  stubView(repository, HoldingsBloc.positionsView, 'PositionList');
  stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
  await tester.pumpApp(
    const HoldingsPage(),
    viewsRepository: repository,
    componentRegistry: buildComponentRegistry(),
    surfaceSize: phone,
  );
  await tester.pumpAndSettle();
}

/// Pumps the Activity tab with its timeline answered.
Future<void> pumpActivity(WidgetTester tester) async {
  final repository = MockViewsRepository();
  stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
  await tester.pumpApp(
    const ActivityPage(),
    viewsRepository: repository,
    surfaceSize: phone,
  );
  await tester.pumpAndSettle();
}
