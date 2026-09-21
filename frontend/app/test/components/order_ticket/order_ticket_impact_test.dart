import 'package:finance_app/components/order_ticket/order_ticket_changes.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_figure.dart';
import 'package:finance_app/components/order_ticket/order_ticket_figure_tile.dart';
import 'package:finance_app/components/order_ticket/order_ticket_impact.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_harness.dart';

void main() {
  const component = OrderTicketComponent();
  OrderTicketData read(Map<String, dynamic> json) =>
      component.read(ViewPayload.fromJson(json));

  group('changedFigures', () {
    test('marks nothing on a first render', () {
      // AC-9: everything is new, and marking all of it would say nothing.
      expect(changedFigures(null, read(orderTicketExample())), isEmpty);
    });

    test('marks nothing when the backend returned the same strings', () {
      final before = read(orderTicketExample());
      final after = read(orderTicketExample());
      expect(changedFigures(before, after), isEmpty);
    });

    test('marks only the figure whose display string changed', () {
      // The comparison is on the **strings the backend sent**. No
      // subtraction, no threshold, no sign — the client cannot tell which
      // way a figure moved and does not need to.
      final before = read(orderTicketExample());
      final after = read(orderTicketExampleWithNotional(r'$99,000.00'));
      expect(changedFigures(before, after), equals(<String>{'notional'}));
    });

    test('ignores a figure the previous render did not carry', () {
      final before = read(orderTicketExample());
      final current = OrderTicketData(
        title: before.title,
        symbol: before.symbol,
        name: before.name,
        side: before.side,
        figures: const <OrderTicketFigure>[
          OrderTicketFigure(name: 'invented', label: 'X', display: 'Y'),
        ],
        fields: before.fields,
        disclosure: before.disclosure,
      );
      expect(changedFigures(before, current), isEmpty);
    });
  });

  group(OrderTicketImpact, () {
    Future<void> pump(
      WidgetTester tester, {
      required Set<String> changed,
      bool isWide = true,
    }) => tester.pumpApp(
      SingleChildScrollView(
        child: OrderTicketImpact(
          figures: read(orderTicketExample()).figures,
          changedFigures: changed,
          isWide: isWide,
        ),
      ),
    );

    testWidgets('renders every figure with its caption', (tester) async {
      await pump(tester, changed: const <String>{});
      expect(find.byType(OrderTicketFigureTile), findsNWidgets(3));
      expect(
        find.text(OrderTicketImpact.caption.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('marks only the figures named as changed', (tester) async {
      // AC-9, at the widget level: the marked tile is the one named, and the
      // others are untouched.
      await pump(tester, changed: const <String>{'notional'});
      final tiles = tester.widgetList<OrderTicketFigureTile>(
        find.byType(OrderTicketFigureTile),
      );
      for (final tile in tiles) {
        expect(
          tile.isChanged,
          tile.figure.name == 'notional',
          reason: '${tile.figure.name} was marked incorrectly',
        );
      }
    });

    testWidgets('announces an updated panel to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, changed: const <String>{'notional'});
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape('${OrderTicketImpact.caption}, updated')),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('stacks the figures when narrow', (tester) async {
      await pump(tester, changed: const <String>{}, isWide: false);
      expect(tester.takeException(), isNull);
      expect(find.byType(OrderTicketFigureTile), findsNWidgets(3));
      // Below each other, not beside — `findsNWidgets(3)` alone is equally
      // true of the wide branch and so proves only that the line ran.
      final first = tester.getTopLeft(find.byType(OrderTicketFigureTile).at(0));
      final second = tester.getTopLeft(
        find.byType(OrderTicketFigureTile).at(1),
      );
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, equals(first.dx));
    });

    testWidgets('sets them beside each other when wide', (tester) async {
      await pump(tester, changed: const <String>{});
      final first = tester.getTopLeft(find.byType(OrderTicketFigureTile).at(0));
      final second = tester.getTopLeft(
        find.byType(OrderTicketFigureTile).at(1),
      );
      expect(second.dx, greaterThan(first.dx));
      expect(second.dy, equals(first.dy));
    });
  });
}
