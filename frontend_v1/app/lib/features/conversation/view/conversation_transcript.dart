import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/component_skeleton_host.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/view/assistant_answer.dart';
import 'package:finance_app/features/conversation/view/assistant_bubbles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Everything the turn has produced so far, oldest first, in the design's
/// frame: bubbles on the right, the `Assistant` label before the agent's
/// first entry of a turn, answers and surfaces at the 15 px gutters.
///
/// Entries are rendered in arrival order and nothing is re-ranked (N-10); a
/// surface appears the moment its payload lands, which is what makes the turn
/// look like it is answering rather than buffering.
class ConversationTranscript extends StatelessWidget {
  /// Renders [entries]; [streaming] adds the dots to the last label.
  const ConversationTranscript({
    required this.entries,
    required this.streaming,
    super.key,
  });

  /// The conversation so far.
  final List<ConversationEntry> entries;

  /// Whether a turn is in flight.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Ask about the portfolio.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    // While the agent has said nothing yet, the label with its dots stands
    // where the first entry will land — the artboard's `Assistant •••`.
    final awaiting = streaming && entries.last is UserSaid;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
      itemCount: entries.length + (awaiting ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return const AssistantLabel(streaming: true);
        }
        final entry = entries[index];
        final previous = index == 0 ? null : entries[index - 1];
        // The label opens each agent turn: once, before the first thing the
        // agent shows after the user spoke.
        final opensTurn =
            entry is! UserSaid && (previous == null || previous is UserSaid);
        final last = index == entries.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: entry is UserSaid ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (opensTurn) ...<Widget>[
                AssistantLabel(streaming: streaming && last),
                const SizedBox(height: 10),
              ],
              ConversationEntryTile(entry: entry, slot: index),
            ],
          ),
        );
      },
    );
  }
}

/// One entry of the transcript.
class ConversationEntryTile extends StatelessWidget {
  /// Renders [entry], which sits at [slot] in the transcript.
  const ConversationEntryTile({
    required this.entry,
    required this.slot,
    super.key,
  });

  /// The entry to render.
  final ConversationEntry entry;

  /// The entry's index — what an edit of its options names (GGU-113).
  final int slot;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      UserSaid(:final text) => UserBubble(text: text),
      // Verbatim. The backend wrote this text and the client never rewrites,
      // truncates or reformats it (N-9).
      AgentSaid(:final text) => AssistantAnswer(text: text),
      // The skeleton is the component's own, found through the same
      // registry the surface will resolve through (spec 0015 OD-3).
      SurfacePending(:final view) => ComponentSkeletonHost(
        registry: context.read<ComponentRegistry>(),
        view: view,
      ),
      // **The same registry, not a parallel path.** A surface the agent asked
      // for is resolved by exactly the widget a `?view=` read goes through,
      // so an unregistered view degrades to the host's placeholder instead of
      // crashing the turn.
      // **Editable, through the same bloc.** The scope is what lets a
      // component with declared inputs render them live; an edit re-requests
      // this one surface with the option changed (ADR-K D-11, GGU-113).
      AgentSurface(:final payload, :final pendingOption, :final rejection) =>
        SurfaceEdits(
          pendingOption: pendingOption,
          rejection: rejection,
          onOptionChanged: (option, value) =>
              context.read<ConversationBloc>().add(
                ConversationSurfaceEdited(
                  slot: slot,
                  option: option,
                  value: value,
                ),
              ),
          child: ComponentHost(
            registry: context.read<ComponentRegistry>(),
            payload: payload,
          ),
        ),
      SurfaceUnavailable(:final view, :final message) => AssistantAnswer(
        text: 'Could not show "$view": $message',
      ),
    };
  }
}
