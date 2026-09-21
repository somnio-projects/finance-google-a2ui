import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(HoldingsAllocationComponent, () {
    const component = HoldingsAllocationComponent();

    test('declares the frozen view id and its A2UI component type', () {
      expect(component.viewId, equals('holdings.allocation.v1'));
      expect(component.a2uiComponent, equals('AllocationSummary'));
    });

    testWidgets('binds every display string verbatim', (tester) async {
      // N-1 / N-4: the figures on screen are exactly the `*.display` strings
      // the backend sent. Nothing is re-formatted and no raw value is shown.
      await tester.pumpApp(
        Builder(
          builder: (context) =>
              component.build(context, holdingsAllocationPayload()),
        ),
      );
      expect(find.text('Allocation by holding'), findsOneWidget);
      expect(find.text('Total market value'), findsOneWidget);
      expect(find.text(r'$65,038.60'), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text(r'$38,550.00'), findsOneWidget);
      expect(find.text('59.27%'), findsOneWidget);
      expect(find.text('Ethereum'), findsOneWidget);
      expect(find.text(r'$15,902.50'), findsOneWidget);
      expect(find.text('24.45%'), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) =>
              component.build(context, holdingsAllocationPayload()),
        ),
      );
      expect(find.text('0.5927249356535964796290203049'), findsNothing);
      expect(find.text('65038.600000000000'), findsNothing);
      expect(find.text('38550.000000'), findsNothing);
    });

    testWidgets('keeps the rows in the order the backend sent them', (
      tester,
    ) async {
      // N-10: ordering is a server-side option, never client behaviour.
      await tester.pumpApp(
        Builder(
          builder: (context) =>
              component.build(context, holdingsAllocationPayload()),
        ),
      );
      final card = tester.widget<HoldingsAllocationCard>(
        find.byType(HoldingsAllocationCard),
      );
      expect(
        card.categories.map((row) => row.categoryKey),
        equals(<String>['BTC', 'ETH', 'SOL', 'LINK', 'DOGE']),
      );
    });

    testWidgets('raises a missing field instead of reconstructing it', (
      tester,
    ) async {
      final incomplete = ViewPayload.fromJson(const <String, dynamic>{
        'view': 'holdings.allocation.v1',
        'title': 'Allocation by holding',
      });
      await tester.pumpApp(
        Builder(builder: (context) => component.build(context, incomplete)),
      );
      expect(tester.takeException(), isA<PayloadContractException>());
    });

    group('register', () {
      test('adds exactly this component to a registry', () {
        final registry = ComponentRegistry();
        register(registry);
        expect(
          registry.lookup('holdings.allocation.v1'),
          isA<HoldingsAllocationComponent>(),
        );
        expect(registry.viewIds, hasLength(1));
      });
    });
  });
}
