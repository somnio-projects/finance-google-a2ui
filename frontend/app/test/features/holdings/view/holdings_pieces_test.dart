import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/holdings/view/holdings_class_rows.dart';
import 'package:finance_app/features/holdings/view/holdings_header_card.dart';
import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// The Holdings header over a gain in [trend], with no rows.
ViewPayload positionsWith(
  String trend,
) => ViewPayload.fromJson(<String, dynamic>{
  'view': 'holdings.positions.v1',
  'title': 'Holdings',
  'total': const <String, dynamic>{
    'label': 'Total value',
    'amount': <String, dynamic>{'amount': '1', 'display': r'$1.00'},
  },
  'gain': <String, dynamic>{
    'amount': const <String, dynamic>{'amount': '-1000', 'display': r'-$1,000'},
    'percent': const <String, dynamic>{'display': '-0.2%', 'value': '-0.002'},
    'period': 'all-time unrealized',
    'trend': trend,
  },
  'ask_label': 'Ask',
  'positions': const <Map<String, dynamic>>[],
});

void main() {
  group(HoldingsHeaderCard, () {
    Future<void> pump(WidgetTester tester, String trend) => tester.pumpApp(
      SizedBox(
        width: 390,
        child: HoldingsHeaderCard(
          positions: positionsWith(trend),
          allocation: holdingsAllocationPayload(),
          groupBy: 'asset_class',
          onGroupBy: (_) {},
        ),
      ),
      componentRegistry: buildComponentRegistry(),
      surfaceSize: const Size(390, 1200),
    );

    testWidgets('a loss takes the down glyph', (tester) async {
      await pump(tester, 'down');
      expect(
        find.text(r'▼ -$1,000 · -0.2% all-time unrealized', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('no move takes the dash', (tester) async {
      await pump(tester, 'flat');
      expect(
        find.text(r'— -$1,000 · -0.2% all-time unrealized', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group(HoldingsClassRows, () {
    testWidgets('a class that did not move prints the dash, muted', (
      tester,
    ) async {
      final payload = ViewPayload.fromJson(const <String, dynamic>{
        'view': 'holdings.allocation.v1',
        'group_by': 'asset_class',
        'categories': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'cash',
            'label': 'Cash',
            'trend': 'flat',
            'change': <String, dynamic>{'display': '0.0%', 'value': '0'},
            'value': <String, dynamic>{
              'amount': '38633',
              'display': r'$38,633',
            },
            'weight': <String, dynamic>{'display': '8%', 'value': '0.08'},
          },
        ],
      });
      await tester.pumpApp(
        SizedBox(width: 390, child: HoldingsClassRows(payload: payload)),
      );
      expect(find.text('— 0.0%'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });
  });

  group(PositionTile, () {
    testWidgets('an unmoved day prints the dash in the stats', (tester) async {
      final row = ViewPayload.fromJson(const <String, dynamic>{
        'view': 'holdings.positions.v1',
        'positions': <Map<String, dynamic>>[
          <String, dynamic>{
            'symbol': 'PG',
            'name': 'Procter & Gamble',
            'detail': r'25 sh · avg $180.00',
            'value': <String, dynamic>{
              'amount': '4200',
              'display': r'$4,200.00',
            },
            'unrealized': <String, dynamic>{
              'amount': <String, dynamic>{
                'amount': '-300',
                'display': r'-$300',
              },
              'percent': <String, dynamic>{
                'display': '-6.7%',
                'value': '-0.067',
              },
              'period': 'all-time',
              'trend': 'down',
            },
            'day': <String, dynamic>{'display': '0.0%', 'value': '0'},
            'day_trend': 'flat',
            'price': <String, dynamic>{'amount': '168', 'display': r'$168.00'},
            'weight': <String, dynamic>{'display': '0.9%', 'value': '0.009'},
            'is_cash': false,
            'ask': <String, dynamic>{'text': 'Tell me about my PG position'},
          },
        ],
      }).rows('positions').single;
      await tester.pumpApp(
        SizedBox(
          width: 390,
          child: PositionTile(
            row: row,
            askLabel: 'Ask',
            expanded: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('— 0.0%'), findsOneWidget);
      expect(find.text(r'▼ -$300 (-6.7%)'), findsOneWidget);
    });
  });
}
