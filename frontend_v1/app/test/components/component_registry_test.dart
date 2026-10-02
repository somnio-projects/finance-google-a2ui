import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubComponent extends ViewComponent {
  const _StubComponent(this.viewId);

  @override
  final String viewId;

  @override
  String get a2uiComponent => 'Stub';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      const SizedBox.shrink();
}

void main() {
  group(ComponentRegistry, () {
    late ComponentRegistry registry;

    setUp(() {
      registry = ComponentRegistry();
    });

    test('starts empty', () {
      expect(registry.viewIds, isEmpty);
      expect(registry.lookup('holdings.allocation.v1'), isNull);
    });

    test('finds a component by the view id it declares', () {
      const component = _StubComponent('a.b.v1');
      registry.register(component);
      expect(registry.lookup('a.b.v1'), same(component));
      expect(registry.viewIds, equals(<String>['a.b.v1']));
    });

    test('returns null for a view id it does not serve', () {
      registry.register(const _StubComponent('a.b.v1'));
      // Not a failure: the backend's catalog grows on its own schedule.
      expect(registry.lookup('c.d.v1'), isNull);
    });

    test('accepts a seventh component without any change to itself', () {
      // ADR-L D-3: the registry is a map that grows, not a switch that is
      // edited. Seven registrations exercise exactly the same code path.
      for (var i = 0; i < 7; i++) {
        registry.register(_StubComponent('view.number$i.v1'));
      }
      expect(registry.viewIds, hasLength(7));
    });

    test(
      'rejects a duplicate view id rather than letting the last one win',
      () {
        registry.register(const _StubComponent('a.b.v1'));
        expect(
          () => registry.register(const _StubComponent('a.b.v1')),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('a.b.v1'),
            ),
          ),
        );
      },
    );
  });
}
