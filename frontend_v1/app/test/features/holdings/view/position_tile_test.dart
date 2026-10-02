import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late List<ViewPayload> rows;

  setUp(() {
    rows = ViewPayload.fromJson(
      CatalogSnapshot.load().exampleFor('PositionList'),
    ).rows('positions');
  });

  ViewPayload cashRow() => ViewPayload.fromJson(const <String, dynamic>{
    'view': 'holdings.positions.v1',
    'positions': <Map<String, dynamic>>[
      <String, dynamic>{
        'symbol': 'USDC',
        'name': 'USD Coin',
        'detail': 'Settlement fund',
        'value': <String, dynamic>{
          'amount': '51764.00',
          'display': r'$51,764.00',
        },
        'day': <String, dynamic>{'value': '0', 'display': '0.0%'},
        'day_trend': 'flat',
        'price': <String, dynamic>{'amount': '1', 'display': r'$1.00'},
        'weight': <String, dynamic>{'value': '0.107', 'display': '10.7%'},
        'is_cash': true,
        'ask': <String, dynamic>{'text': 'What is my cash doing?'},
      },
    ],
  }).rows('positions').single;

  group(PositionTile, () {
    testWidgets('a collapsed row prints its four figures and no details', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(
          width: 390,
          child: PositionTile(
            row: rows[2],
            askLabel: 'Ask',
            expanded: false,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Solana'), findsOneWidget);
      expect(find.text(r'375.5 SOL · avg $177.70'), findsOneWidget);
      expect(find.text(r'$57,226.20'), findsOneWidget);
      expect(find.text(r'▼ -$9,500 (-14.2%)'), findsOneWidget);
      expect(find.text('Price'), findsNothing);
    });

    testWidgets(
      'the settlement row prints the day move muted and never expands',
      (tester) async {
        await tester.pumpApp(
          SizedBox(
            width: 390,
            child: PositionTile(
              row: cashRow(),
              askLabel: 'Ask',
              expanded: true,
              onTap: () {},
            ),
          ),
        );
        expect(find.text('Settlement fund'), findsOneWidget);
        expect(find.text('— 0.0%'), findsOneWidget);
        expect(find.text('Ask'), findsNothing);
      },
    );

    testWidgets('a down day takes the loss glyph in the stats', (tester) async {
      await tester.pumpApp(
        SizedBox(
          width: 390,
          child: PositionTile(
            row: rows[3],
            askLabel: 'Ask',
            expanded: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('▼ -2.4%'), findsWidgets);
    });

    testWidgets("the hand-off opens the assistant with the row's question", (
      tester,
    ) async {
      String? opened;
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => Scaffold(
              body: SizedBox(
                width: 390,
                child: PositionTile(
                  row: rows[0],
                  askLabel: 'Ask the assistant',
                  expanded: true,
                  onTap: () {},
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
      await tester.tap(find.text('Ask the assistant'));
      await tester.pumpAndSettle();
      expect(opened, 'Tell me about my BTC position');
    });
  });
}
