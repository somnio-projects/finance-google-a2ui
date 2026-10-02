import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

/// Every model is a value: two instances built apart compare equal. The
/// inputs are runtime values on purpose — `const` instances are canonical,
/// and `identical` would short-circuit the comparison under test.
void main() {
  final id = <String>['s'].single;

  test('agent messages compare by value', () {
    expect(
      AgentFunctionResponse(
        functionCallId: id,
        error: FunctionError(code: id, message: id),
      ),
      AgentFunctionResponse(
        functionCallId: id,
        error: FunctionError(code: id, message: id),
      ),
    );
    expect(
      DecodedMessage(DeleteSurface(id)),
      DecodedMessage(DeleteSurface(id)),
    );
  });

  test('renderer messages compare by value', () {
    ActionMessage action() => ActionMessage(
      name: id,
      surfaceId: id,
      sourceComponentId: id,
      timestamp: id,
    );
    expect(action(), action());
  });

  test('surfaces and trees compare by value', () {
    expect(Surface(id: id), Surface(id: id));
    expect(
      SurfaceTree(
        root: RenderNode(ComponentNode(id: id, component: id)),
      ),
      SurfaceTree(
        root: RenderNode(ComponentNode(id: id, component: id)),
      ),
    );
  });
}
