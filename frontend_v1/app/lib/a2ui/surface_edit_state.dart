import 'package:equatable/equatable.dart';

/// The host's answer to the last edit of one component: which option is
/// being re-rendered, and the agent's sentence when it refused one.
///
/// Both are drawn by the component through `SurfaceEdits`, never composed
/// by it — the same contract the v0.9 Assistant kept (GGU-113), now fed by
/// `callAgentFunction(renderView)` and its `agentFunctionResponse`.
final class SurfaceEditState extends Equatable {
  /// Creates the state.
  const SurfaceEditState({this.pendingOption, this.rejection});

  /// The option in flight, or null.
  final String? pendingOption;

  /// `agentFunctionResponse.error.message` for the last refused edit, or null.
  final String? rejection;

  @override
  List<Object?> get props => <Object?>[pendingOption, rejection];
}

/// The key one component's [SurfaceEditState] is filed under.
String editKey(String surfaceId, String componentId) =>
    '$surfaceId/$componentId';
