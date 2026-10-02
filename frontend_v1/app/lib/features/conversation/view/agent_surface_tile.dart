import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/surface_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One A2UI surface of the transcript, drawn by the [SurfaceHost] and wired
/// to the conversation's bloc.
///
/// **The same registry, not a parallel path**: every node resolves through
/// the `ComponentRegistry` a REST read goes through. **Editable and
/// tappable through the same bloc**: an option edit becomes
/// `callAgentFunction("renderView")` and a bar tap a v1.0 `action`
/// (ADR-M D-6, D-7), each scoped to the component that raised it.
class AgentSurfaceTile extends StatelessWidget {
  /// Draws the surface [surfaceId].
  const AgentSurfaceTile({required this.surfaceId, super.key});

  /// The `createSurface.surfaceId`.
  final String surfaceId;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ConversationBloc>();
    final surface = context.select<ConversationBloc, Surface?>(
      (bloc) => bloc.state.surfaces[surfaceId],
    );
    final edits = context
        .select<ConversationBloc, Map<String, SurfaceEditState>>(
          (bloc) => bloc.state.edits,
        );
    // An entry outlives its surface by at most one frame: a deleteSurface
    // removes both in the same state.
    if (surface == null) return const SizedBox.shrink();
    return SurfaceHost(
      surface: surface,
      catalog: context.read<Catalog>(),
      registry: context.read<ComponentRegistry>(),
      edits: edits,
      onOptionChanged: (componentId, option, value) => bloc.add(
        ConversationSurfaceEdited(
          surfaceId: surfaceId,
          componentId: componentId,
          option: option,
          value: value,
        ),
      ),
      onAction: (componentId, request) => bloc.add(
        ConversationActionSent(
          surfaceId: surfaceId,
          componentId: componentId,
          request: request,
        ),
      ),
    );
  }
}
