import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

import '../helpers/examples.dart';

Surface _surface(List<ComponentNode> nodes) =>
    const Surface(id: 's').withComponents(nodes);

ComponentNode _node(String id, String type, [List<String> kids = const []]) =>
    ComponentNode(id: id, component: type, children: kids);

/// Spec `frontend_v1/0001` AC-3 and ADR-M D-4.
void main() {
  final catalog = financeCatalog();

  group('composeTree', () {
    test('admits the ticket with its payoff child', () {
      final outcome = const SurfaceProcessor().process(
        const SurfaceSet(),
        decodeAgentDataPart(example('surface.order_ticket_with_payoff.json')),
      );
      final tree = composeTree(
        outcome.surfaces.surfaces.values.single,
        catalog,
      );
      expect(tree.errors, isEmpty);
      expect(tree.root!.node.component, 'MultiLegOrderTicket');
      expect(tree.root!.children.single.node.component, 'RiskPayoffChart');
    });

    test('is empty while root is buffered', () {
      expect(composeTree(const Surface(id: 's'), catalog), const SurfaceTree());
    });

    test('drops a payoff under Section, keeps its sibling', () {
      final tree = composeTree(
        _surface(<ComponentNode>[
          _node('root', 'Section', <String>['bad', 'ok', 'later']),
          _node('bad', 'RiskPayoffChart'),
          _node('ok', 'TaxLotTable'),
        ]),
        catalog,
      );
      expect(tree.root!.children.map((n) => n.node.id), <String>['ok']);
      final error = tree.errors.single;
      expect(error.code, 'UNALLOWED_PARENT');
      expect(error.surfaceId, 's');
      expect(error.path, '/components/bad/component');
    });

    test('refuses a root that may not sit under Surface', () {
      final tree = composeTree(
        _surface(<ComponentNode>[_node('root', 'RiskPayoffChart')]),
        catalog,
      );
      expect(tree.root, isNull);
      expect(tree.errors.single.code, 'UNALLOWED_PARENT');
    });

    test('reports UNALLOWED_CHILD from the parent side', () {
      const strict = Catalog(
        catalogId: 'c',
        components: <String, CompositionRules>{
          'Section': CompositionRules(allowedChildren: <String>['TaxLotTable']),
          'OrderTicket': CompositionRules(),
        },
      );
      final tree = composeTree(
        _surface(<ComponentNode>[
          _node('root', 'Section', <String>['t']),
          _node('t', 'OrderTicket'),
        ]),
        strict,
      );
      expect(tree.root!.children, isEmpty);
      expect(tree.errors.single.code, 'UNALLOWED_CHILD');
    });

    test('reports a type the catalog does not declare, and a cycle', () {
      final tree = composeTree(
        _surface(<ComponentNode>[
          _node('root', 'Section', <String>['x', 'root']),
          _node('x', 'Carousel'),
        ]),
        const Catalog(
          catalogId: 'c',
          components: <String, CompositionRules>{'Section': CompositionRules()},
        ),
      );
      expect(tree.errors.map((e) => e.code), <String>[
        'VALIDATION_FAILED',
        'VALIDATION_FAILED',
      ]);
      expect(tree.errors.first.message, contains('Carousel'));
      expect(tree.errors.last.message, contains('contains itself'));
    });

    test('nodes compare by value', () {
      expect(RenderNode(_node('a', 'T')), RenderNode(_node('a', 'T')));
    });
  });
}
