import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

RendererError _failure(Object? json) =>
    (decodeAgentMessage(json) as DecodeFailure).error;

AgentMessage _message(Map<String, Object?> body) => (decodeAgentMessage(
  <String, Object?>{'version': 'v1.0', ...body},
) as DecodedMessage).message;

void main() {
  group('decodeAgentMessage reads', () {
    test('a bare createSurface with defaults', () {
      expect(
        _message(<String, Object?>{
          'createSurface': <String, Object?>{'surfaceId': 's'},
        }),
        const CreateSurface(surfaceId: 's'),
      );
    });

    test('updateComponents, deleteSurface and callRendererFunction', () {
      expect(
        _message(<String, Object?>{
          'updateComponents': <String, Object?>{
            'surfaceId': 's',
            'components': <Object?>[
              <String, Object?>{'id': 'root', 'component': 'Section'},
            ],
          },
        }),
        const UpdateComponents(
          surfaceId: 's',
          components: <ComponentNode>[
            ComponentNode(
              id: 'root',
              component: 'Section',
              properties: <String, Object?>{
                'id': 'root',
                'component': 'Section',
              },
            ),
          ],
        ),
      );
      expect(
        _message(<String, Object?>{
          'deleteSurface': <String, Object?>{'surfaceId': 's'},
        }),
        const DeleteSurface('s'),
      );
      expect(
        _message(<String, Object?>{
          'callRendererFunction': <String, Object?>{
            'functionCallId': 'f',
            'callFunction': <String, Object?>{'call': 'openUrl'},
          },
        }),
        const CallRendererFunction(functionCallId: 'f', call: 'openUrl'),
      );
    });

    test('updateDataModel with the default path', () {
      expect(
        _message(<String, Object?>{
          'updateDataModel': <String, Object?>{'surfaceId': 's', 'value': 1},
        }),
        const UpdateDataModel(surfaceId: 's', value: 1),
      );
    });
  });

  group('decodeAgentMessage refuses', () {
    test('a non-object, a wrong version and two keys', () {
      expect(_failure('x').path, '');
      expect(_failure(<String, Object?>{'version': 'v0.9'}).path, '/version');
      expect(
        _failure(<String, Object?>{
          'version': 'v1.0',
          'deleteSurface': <String, Object?>{'surfaceId': 's'},
          'createSurface': <String, Object?>{'surfaceId': 's'},
        }).message,
        contains('exactly one'),
      );
    });

    test('an unknown kind, naming the surface it was about', () {
      final error = _failure(<String, Object?>{
        'version': 'v1.0',
        'paintSurface': <String, Object?>{'surfaceId': 's'},
      });
      expect(error.code, 'VALIDATION_FAILED');
      expect(error.path, '/paintSurface');
      expect(error.surfaceId, 's');
    });

    test('updateDataModel with no value', () {
      expect(
        _failure(<String, Object?>{
          'version': 'v1.0',
          'updateDataModel': <String, Object?>{'surfaceId': 's'},
        }).path,
        '/updateDataModel/value',
      );
    });

    test('a function response with neither value nor error', () {
      expect(
        _failure(<String, Object?>{
          'version': 'v1.0',
          'agentFunctionResponse': <String, Object?>{'functionCallId': 'f'},
        }).message,
        contains('value or an error'),
      );
    });

    test('components that are not an array, and a wrong field type', () {
      expect(
        _failure(<String, Object?>{
          'version': 'v1.0',
          'updateComponents': <String, Object?>{
            'surfaceId': 's',
            'components': 'root',
          },
        }).path,
        '/updateComponents/components',
      );
      expect(
        _failure(<String, Object?>{
          'version': 'v1.0',
          'createSurface': <String, Object?>{'surfaceId': 's', 'catalogId': 1},
        }).path,
        '/createSurface/catalogId',
      );
    });
  });

  test('outcomes compare by value', () {
    expect(decodeAgentMessage(null), decodeAgentMessage(null));
    expect(
      const A2uiFormatException('/x', 'bad').toString(),
      'A2uiFormatException(/x): bad',
    );
  });
}
