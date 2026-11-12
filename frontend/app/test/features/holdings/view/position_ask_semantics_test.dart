import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/catalog_snapshot.dart';

void main() {
  group('PositionAsk semantics (GGU-158)', () {
    testWidgets('is its own button node and opens the assistant, apart '
        'from the card', (tester) async {
      final handle = tester.ensureSemantics();
      final row = ViewPayload.fromJson(
        CatalogSnapshot.load().exampleFor('PositionList'),
      ).rows('positions').first;
      var toggled = 0;
      String? opened;
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => Scaffold(
              body: SizedBox(
                width: 390,
                child: PositionTile(
                  row: row,
                  askLabel: 'Ask the assistant about this',
                  expanded: true,
                  onTap: () => toggled++,
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.conversation,
            builder: (context, state) {
              opened = state.uri.queryParameters[AppRoutes.askParameter];
              return const Text('assistant');
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );

      final cta = tester.getSemantics(
        find.bySemanticsLabel('Ask the assistant about this'),
      );
      expect(cta.label, equals('Ask the assistant about this'));
      expect(cta.flagsCollection.isButton, isTrue);
      expect(cta.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      // No ancestor is a button: a button's children are presentational
      // on the web, which is how the CTA vanished into the card.
      for (var up = cta.parent; up != null; up = up.parent) {
        expect(up.flagsCollection.isButton, isFalse);
      }

      // The card's own button is a different node and does not carry it.
      final card = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^${row.text('name')} ')),
      );
      expect(card.id, isNot(equals(cta.id)));
      expect(card.label, isNot(contains('Ask the assistant')));

      tester.semantics.tap(
        find.semantics.byLabel('Ask the assistant about this'),
      );
      await tester.pumpAndSettle();
      expect(opened, equals(row.text('ask.text')));
      expect(toggled, equals(0));
      handle.dispose();
    });

    testWidgets('the card still toggles on its own tap action', (tester) async {
      final handle = tester.ensureSemantics();
      final row = ViewPayload.fromJson(
        CatalogSnapshot.load().exampleFor('PositionList'),
      ).rows('positions').first;
      var toggled = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PositionTile(
              row: row,
              askLabel: 'Ask the assistant about this',
              expanded: true,
              onTap: () => toggled++,
            ),
          ),
        ),
      );
      tester.semantics.tap(
        find.semantics.byLabel(RegExp('^${row.text('name')} ')),
      );
      await tester.pump();
      expect(toggled, equals(1));
      handle.dispose();
    });
  });
}
