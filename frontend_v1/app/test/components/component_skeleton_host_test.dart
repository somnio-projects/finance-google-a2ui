import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/component_skeleton_host.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// A component that draws its own skeleton.
class _ShapedComponent extends ViewComponent {
  const _ShapedComponent();

  @override
  String get viewId => 'shaped.v1';

  @override
  String get a2uiComponent => 'Shaped';

  @override
  Widget build(BuildContext context, ViewPayload payload) => const SizedBox();

  @override
  Widget skeleton(BuildContext context) => const Text('shaped skeleton');
}

/// A component that leaves the seam's default alone.
class _PlainComponent extends ViewComponent {
  const _PlainComponent();

  @override
  String get viewId => 'plain.v1';

  @override
  String get a2uiComponent => 'Plain';

  @override
  Widget build(BuildContext context, ViewPayload payload) => const SizedBox();
}

void main() {
  group(ComponentSkeletonHost, () {
    late ComponentRegistry registry;

    setUp(() {
      registry = ComponentRegistry()
        ..register(const _ShapedComponent())
        ..register(const _PlainComponent());
    });

    testWidgets('draws the skeleton the component drew for itself', (
      tester,
    ) async {
      await tester.pumpApp(
        ComponentSkeletonHost(registry: registry, view: 'shaped.v1'),
      );
      expect(find.text('shaped skeleton'), findsOneWidget);
      expect(find.byType(SurfaceSkeleton), findsNothing);
    });

    testWidgets('a component without a shape gets the generic surface', (
      tester,
    ) async {
      // The seam's default (ADR-L D-3: overriding is optional, and the
      // Assistant's bars-and-pills card is what a component inherits).
      await tester.pumpApp(
        ComponentSkeletonHost(registry: registry, view: 'plain.v1'),
      );
      await tester.pump();
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
    });

    testWidgets('a view this build does not render gets the generic surface', (
      tester,
    ) async {
      await tester.pumpApp(
        ComponentSkeletonHost(registry: registry, view: 'unknown.v9'),
      );
      await tester.pump();
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
    });
  });
}
