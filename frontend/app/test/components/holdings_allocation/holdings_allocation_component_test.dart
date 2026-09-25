import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'holdings_allocation_harness.dart';

void main() {
  group(HoldingsAllocationComponent, () {
    const component = HoldingsAllocationComponent();
    late Map<String, dynamic> example;

    setUp(() {
      // AC-6: the example is **read** from the backend's generated snapshot,
      // not copied. A rename, a dropped field or a changed example turns this
      // suite red rather than drifting quietly (rule `frontend/testing.md` §5).
      example = CatalogSnapshot.load().exampleFor('HoldingsSummary');
    });

    test('declares the frozen view id and its A2UI component type', () {
      expect(component.viewId, equals('holdings.allocation.v1'));
      expect(component.a2uiComponent, equals('HoldingsSummary'));
    });

    testWidgets('binds every display string verbatim', (tester) async {
      // AC-1 / N-1: the figures on screen are exactly the `*.display` strings
      // the backend sent. Nothing is re-formatted.
      await tester.pumpApp(
        _subject(component, example),
        surfaceSize: const Size(1000, 1400),
      );
      expect(find.text('Allocation by holding'), findsOneWidget);
      expect(
        find.text(r'▲ +$61,204 (+14.5%)  all-time', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(r'$482,915.20'), findsOneWidget);
      for (final row in <List<String>>[
        <String>['Bitcoin', r'$134,925.00', '27.94%'],
        <String>['Ethereum', r'$104,400.00', '21.62%'],
        <String>['Other', r'$87,140.00', '18.04%'],
      ]) {
        expect(find.text(row[0]), findsOneWidget);
        expect(find.text(row[1]), findsOneWidget);
        expect(find.text(row[2]), findsOneWidget);
      }
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // AC-1 / N-4. The raw members reach the arc geometry and nothing else;
      // this is the assertion that catches it if one leaks into a `Text`.
      await tester.pumpApp(
        _subject(component, example),
        surfaceSize: const Size(1000, 1400),
      );
      expect(find.text('0.2793968796177879677425767505'), findsNothing);
      expect(find.text('482915.200000000000'), findsNothing);
      expect(find.text('134925.0000000000'), findsNothing);
    });

    test('reads the raw weight only as geometry, never as text', () {
      // The two paths are disjoint by construction: `weight` is a double that
      // came through the one allow-listed seam (ADR-L D-14) and
      // `weightDisplay` is the backend's string. Neither is derived from the
      // other, and this pins that they disagree in type as well as in value.
      final data = component.read(ViewPayload.fromJson(example));
      final bitcoin = data.categories.first;
      expect(bitcoin.weight, closeTo(0.279396879617788, 1e-15));
      expect(bitcoin.weightDisplay, equals('27.94%'));
      expect(data.weights, hasLength(data.categories.length));
    });

    test('keeps the rows in the order the backend sent them', () {
      // N-10: ordering is a server-side option (`sort`), never client
      // behaviour.
      final data = component.read(ViewPayload.fromJson(example));
      expect(
        data.categories.map((row) => row.key),
        equals(<String>['BTC', 'ETH', 'SOL', 'USDC', 'LINK', 'other']),
      );
    });

    test('reads a single-holding payload', () {
      // Named for what it does. AC-3 — that the backend's residual bucket
      // renders as an ordinary row — is proved by
      // `holdings_allocation_card_test.dart::renders one legend row per
      // category, residual included`, whose fixture has an `other` row; this
      // one only trims the example to its first category, which is BTC.
      final data = component.read(
        ViewPayload.fromJson(withOneCategory(example)),
      );
      expect(data.categories, hasLength(1));
      expect(data.isEmpty, isFalse);
    });

    test('reports an empty portfolio as an empty model', () {
      final data = component.read(
        ViewPayload.fromJson(withNoCategories(example)),
      );
      expect(data.isEmpty, isTrue);
      expect(data.weights, isEmpty);
      expect(data.totalDisplay, equals(r'$482,915.20'));
    });

    testWidgets('raises a missing field instead of reconstructing it', (
      tester,
    ) async {
      // N-3, through `text`.
      final incomplete = ViewPayload.fromJson(const <String, dynamic>{
        'view': 'holdings.allocation.v1',
        'title': 'Allocation by holding',
      });
      await tester.pumpApp(
        Builder(builder: (context) => component.build(context, incomplete)),
      );
      expect(tester.takeException(), isA<PayloadContractException>());
    });

    test('raises when a weight is not a decimal, rather than guessing', () {
      // N-3, through `geometry`. A share the client cannot read is a contract
      // violation naming the path, not a slice silently sized zero.
      expect(
        () => component.read(ViewPayload.fromJson(withBadWeight(example))),
        throwsA(isA<PayloadContractException>()),
      );
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

Widget _subject(
  HoldingsAllocationComponent component,
  Map<String, dynamic> example,
) => Builder(
  builder: (context) => component.build(context, ViewPayload.fromJson(example)),
);
