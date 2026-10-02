import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

import '../helpers/examples.dart';

void main() {
  group('DataPart', () {
    test('recognises only the A2UI mime type', () {
      expect(isA2uiDataPart('x'), isFalse);
      expect(
        isA2uiDataPart(<String, Object?>{'kind': 'data', 'metadata': 1}),
        isFalse,
      );
      expect(
        isA2uiDataPart(<String, Object?>{
          'kind': 'data',
          'metadata': <String, Object?>{'mimeType': 'application/json'},
        }),
        isFalse,
      );
    });

    test('a part with no array yields one failure', () {
      final outcome = decodeAgentDataPart(<String, Object?>{
        'kind': 'data',
        'metadata': <String, Object?>{'mimeType': A2uiProtocol.mimeType},
        'data': 'nope',
      });
      expect((outcome.single as DecodeFailure).error.path, '/data');
      expect(() => decodeRendererDataPart('x'), throwsFormatException);
    });
  });

  group('decodeRendererMessage', () {
    test('reads an error and round-trips it', () {
      const error = RendererError(
        code: 'UNALLOWED_PARENT',
        message: 'no',
        surfaceId: 's',
        path: '/components/0/component',
      );
      expect(decodeRendererMessage(error.toJson()), error);
      const generic = RendererError(
        code: 'UNKNOWN_FUNCTION',
        message: 'no',
        functionCallId: 'f',
      );
      expect(decodeRendererMessage(generic.toJson()), generic);
    });

    test('refuses a wrong version or a malformed body', () {
      expect(
        () => decodeRendererMessage(<String, Object?>{'version': 'v0.9'}),
        throwsFormatException,
      );
      expect(
        () => decodeRendererMessage(<String, Object?>{
          'version': 'v1.0',
          'error': 'x',
        }),
        throwsFormatException,
      );
    });

    test('messages compare by value', () {
      final call = decodeRendererDataPart(
        example('call_agent_function.render_view.json'),
      ).single;
      final again = decodeRendererDataPart(
        example('call_agent_function.render_view.json'),
      ).single;
      expect(call, again);
      final action = decodeRendererDataPart(
        example('action.drill_attribution.json'),
      ).single;
      expect(action, isA<ActionMessage>());
      expect(action == call, isFalse);
    });
  });

  group('ComponentNode and Accessibility', () {
    test('reads a single child, accessibility and no data binding', () {
      final node = ComponentNode.fromJson(const <String, Object?>{
        'id': 'a',
        'component': 'Card',
        'child': 'b',
        'data': 'not a binding',
        'accessibility': <String, Object?>{
          'label': 'Card',
          'description': <String, Object?>{'path': '/d'},
        },
      }, '/c');
      expect(node.children, <String>['b']);
      expect(node.dataPath, isNull);
      expect(node.accessibility, const Accessibility(label: 'Card'));
      expect(Accessibility.fromJson('x'), const Accessibility());
    });

    test('refuses a template child list', () {
      expect(
        () => ComponentNode.fromJson(const <String, Object?>{
          'id': 'a',
          'component': 'List',
          'children': <String, Object?>{'componentId': 'b', 'path': '/l'},
        }, '/c'),
        throwsA(isA<A2uiFormatException>()),
      );
    });
  });

  group('Catalog', () {
    test('reads rules, functions and the omitted-means-any default', () {
      final catalog = financeCatalog();
      expect(catalog.functions, <String>{'renderView'});
      final payoff = catalog.components['RiskPayoffChart']!;
      expect(payoff.acceptsParent('OrderTicket'), isTrue);
      expect(payoff.acceptsParent('Section'), isFalse);
      expect(payoff.acceptsChild('anything'), isTrue);
      expect(const CompositionRules().acceptsParent('x'), isTrue);
      expect(catalog, financeCatalog());
    });

    test('refuses a document with no id or a malformed component', () {
      expect(
        () => Catalog.fromJson(const <String, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => Catalog.fromJson(const <String, Object?>{
          'catalogId': 'c',
          'components': <String, Object?>{'X': 1},
        }),
        throwsFormatException,
      );
      expect(
        Catalog.fromJson(const <String, Object?>{'catalogId': 'c'}).components,
        isEmpty,
      );
    });
  });

  test('rendererCapabilities is the extension spec shape', () {
    expect(rendererCapabilities(<String>['c']), <String, Object?>{
      'v1.0': <String, Object?>{
        'supportedCatalogIds': <String>['c'],
      },
    });
  });
}
