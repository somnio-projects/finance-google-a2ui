import 'package:finance_app/features/home/view/home_hero.dart';
import 'package:finance_app/features/home/view/home_movers.dart';
import 'package:finance_app/features/home/view/home_questions.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';

/// The hero example with its `change.trend` replaced — the one field the
/// glyph and the tone are read from (N-5: the enum, never the sign).
Map<String, dynamic> heroWithTrend(String trend) {
  final example = CatalogSnapshot.load().exampleFor('PortfolioSummary');
  final change = Map<String, dynamic>.from(example['change'] as Map);
  change['trend'] = trend;
  return <String, dynamic>{...example, 'change': change};
}

/// The example with the first mover's `trend` replaced.
Map<String, dynamic> moversWithTrend(String trend) {
  final example = CatalogSnapshot.load().exampleFor('PortfolioSummary');
  final movers = (example['movers'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return <String, dynamic>{
    ...example,
    'movers': <Map<String, dynamic>>[
      <String, dynamic>{...movers.first, 'trend': trend},
      ...movers.skip(1),
    ],
  };
}

void main() {
  group(HomeHero, () {
    for (final (trend, glyph) in <(String, String)>[
      ('down', '▼'),
      ('flat', '—'),
    ]) {
      testWidgets('a $trend change takes the $glyph glyph', (tester) async {
        await tester.pumpApp(
          HomeHero(
            payload: ViewPayload.fromJson(heroWithTrend(trend)),
            range: '1d',
            onRangeSelected: (_) {},
          ),
        );
        expect(
          find.text('$glyph +\$3,240.18 (+0.68%)  today', findRichText: true),
          findsOneWidget,
        );
      });
    }
  });

  group(HomeMovers, () {
    testWidgets('a flat mover takes the dash and the muted tone', (
      tester,
    ) async {
      await tester.pumpApp(
        HomeMovers(payload: ViewPayload.fromJson(moversWithTrend('flat'))),
      );
      final change = tester.widget<Text>(find.text('— +4.2%'));
      expect(
        change.style?.color,
        AppTheme.light.extension<HomeTokens>()!.muted,
      );
    });
  });

  group(HomeQuestions, () {
    testWidgets('a tapped question opens the assistant', (tester) async {
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => HomeQuestions(
              payload: ViewPayload.fromJson(
                CatalogSnapshot.load().exampleFor('PortfolioSummary'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.conversation,
            builder: (context, state) => const Text('assistant'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.tap(find.text('💬 Tax impact of selling NVDA?'));
      await tester.pumpAndSettle();
      expect(find.text('assistant'), findsOneWidget);
    });
  });
}
