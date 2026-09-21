import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _RenderingComponent extends ViewComponent {
  const _RenderingComponent();

  @override
  String get viewId => 'holdings.allocation.v1';

  @override
  String get a2uiComponent => 'Stub';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      Text(payload.text('title'));
}

class _DemandingComponent extends ViewComponent {
  const _DemandingComponent();

  @override
  String get viewId => 'holdings.allocation.v1';

  @override
  String get a2uiComponent => 'Stub';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      Text(payload.text('total.amount.nope'));
}

void main() {
  group(ComponentHost, () {
    late ComponentRegistry registry;

    setUp(() {
      registry = ComponentRegistry();
    });

    testWidgets('renders the component registered for the payload view', (
      tester,
    ) async {
      registry.register(const _RenderingComponent());
      await tester.pumpApp(
        ComponentHost(registry: registry, payload: holdingsAllocationPayload()),
      );
      expect(find.text('Allocation by holding'), findsOneWidget);
    });

    testWidgets('shows a placeholder when no component serves the view', (
      tester,
    ) async {
      await tester.pumpApp(
        ComponentHost(registry: registry, payload: holdingsAllocationPayload()),
      );
      expect(
        find.textContaining('No component for "holdings.allocation.v1"'),
        findsOneWidget,
      );
    });

    testWidgets('shows the violation when the payload breaks its contract', (
      tester,
    ) async {
      // N-3: the missing field is surfaced, not reconstructed and not
      // swallowed — the person looking at the screen can raise it.
      registry.register(const _DemandingComponent());
      await tester.pumpApp(
        ComponentHost(registry: registry, payload: holdingsAllocationPayload()),
      );
      expect(find.textContaining('Contract violation'), findsOneWidget);
      expect(find.textContaining('total.amount.nope'), findsOneWidget);
    });
  });
}
