import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

import '../helpers/examples.dart';

const ComponentNode _root = ComponentNode(
  id: 'root',
  component: 'Section',
  children: <String>['a'],
);
const ComponentNode _child = ComponentNode(id: 'a', component: 'TaxLotTable');

ProcessOutcome _run(List<AgentMessage> messages, [SurfaceSet? start]) =>
    const SurfaceProcessor().process(start ?? const SurfaceSet(), <Decoded>[
      for (final message in messages) DecodedMessage(message),
    ]);

/// Spec `frontend_v1/0001` AC-2.
void main() {
  group('SurfaceProcessor', () {
    test('builds both surface examples with root and data', () {
      for (final name in <String>[
        'surface.portfolio_summary.json',
        'surface.order_ticket_with_payoff.json',
      ]) {
        final outcome = _run(agentMessages(name));
        final surface = outcome.surfaces.surfaces.values.single;
        expect(outcome.errors, isEmpty, reason: name);
        expect(surface.hasRoot, isTrue, reason: name);
        expect(surface.read('/root/view'), isA<String>(), reason: name);
      }
    });

    test('buffers components until root arrives', () {
      final created = _run(<AgentMessage>[
        const CreateSurface(surfaceId: 's'),
        const UpdateComponents(
          surfaceId: 's',
          components: <ComponentNode>[_child],
        ),
      ]);
      expect(created.surfaces['s']!.hasRoot, isFalse);
      final rooted = _run(<AgentMessage>[
        const UpdateComponents(
          surfaceId: 's',
          components: <ComponentNode>[_root],
        ),
      ], created.surfaces);
      expect(rooted.surfaces['s']!.hasRoot, isTrue);
      expect(rooted.surfaces['s']!.components.keys, <String>['a', 'root']);
    });

    test('applies updateDataModel at a path and deletes on null', () {
      final outcome = _run(<AgentMessage>[
        const CreateSurface(
          surfaceId: 's',
          dataModel: <String, Object?>{
            'root': <String, Object?>{'view': 'x'},
          },
        ),
        const UpdateDataModel(surfaceId: 's', path: '/root/view', value: 'y'),
        const UpdateDataModel(surfaceId: 's', path: '/extra', value: 1),
        const UpdateDataModel(surfaceId: 's', path: '/extra', value: null),
      ]);
      expect(outcome.surfaces['s']!.dataModel, <String, Object?>{
        'root': <String, Object?>{'view': 'y'},
      });
    });

    test('applies the render_view response to the summary surface', () {
      final outcome = _run(<AgentMessage>[
        ...agentMessages('surface.portfolio_summary.json'),
        ...agentMessages('agent_function_response.render_view.json'),
      ]);
      expect(
        outcome.surfaces['turn-7f3a-0']!.read('/root/options/range'),
        '1y',
      );
      expect(outcome.responses.single.functionCallId, 'call-01');
    });

    test('deletes a surface', () {
      final outcome = _run(<AgentMessage>[
        const CreateSurface(surfaceId: 's'),
        const DeleteSurface('s'),
      ]);
      expect(outcome.surfaces.surfaces, isEmpty);
    });

    test('reports each failing message and applies the rest', () {
      final outcome = const SurfaceProcessor().process(const SurfaceSet(), <
        Decoded
      >[
        const DecodedMessage(CreateSurface(surfaceId: 's')),
        const DecodedMessage(CreateSurface(surfaceId: 's')),
        const DecodedMessage(UpdateComponents(surfaceId: 'x', components: [])),
        const DecodedMessage(UpdateDataModel(surfaceId: 'x', value: 1)),
        const DecodedMessage(DeleteSurface('x')),
        const DecodedMessage(UpdateDataModel(surfaceId: 's', value: 'scalar')),
        const DecodeFailure(
          RendererError(code: 'VALIDATION_FAILED', message: 'bad'),
        ),
        const DecodedMessage(
          CallRendererFunction(functionCallId: 'f', call: 'openUrl'),
        ),
        const DecodedMessage(UpdateDataModel(surfaceId: 's', value: null)),
      ]);
      expect(outcome.errors.map((error) => error.code), <String>[
        'SURFACE_EXISTS',
        'SURFACE_NOT_FOUND',
        'SURFACE_NOT_FOUND',
        'SURFACE_NOT_FOUND',
        'VALIDATION_FAILED',
        'VALIDATION_FAILED',
        'UNKNOWN_FUNCTION',
      ]);
      expect(outcome.errors.last.functionCallId, 'f');
      expect(outcome.surfaces['s'], isNotNull);
      expect(outcome.surfaces['s']!.dataModel, isEmpty);
    });

    test('outcomes and sets compare by value', () {
      expect(_run(const <AgentMessage>[]), _run(const <AgentMessage>[]));
      expect(
        const SurfaceSet().put(const Surface(id: 's')),
        const SurfaceSet(<String, Surface>{'s': Surface(id: 's')}),
      );
    });
  });
}
