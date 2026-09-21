import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Everything the turn has produced so far, oldest first.
///
/// Entries are rendered in arrival order and nothing is re-ranked (N-10); a
/// surface appears the moment its payload lands, which is what makes the turn
/// look like it is answering rather than buffering.
class ConversationTranscript extends StatelessWidget {
  /// Renders [entries].
  const ConversationTranscript({required this.entries, super.key});

  /// The conversation so far.
  final List<ConversationEntry> entries;

  @override
  Widget build(BuildContext context) {
    final spacing = AppSpacing.of(context);
    if (entries.isEmpty) {
      return const Center(child: Text('Ask about the portfolio.'));
    }
    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: entries.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) =>
          ConversationEntryTile(entry: entries[index]),
    );
  }
}

/// One entry of the transcript.
class ConversationEntryTile extends StatelessWidget {
  /// Renders [entry].
  const ConversationEntryTile({required this.entry, super.key});

  /// The entry to render.
  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      UserSaid(:final text) => _Bubble(text: text, fromUser: true),
      AgentSaid(:final text) => _Bubble(text: text, fromUser: false),
      // **The same registry, not a parallel path.** A surface the agent asked
      // for is resolved by exactly the widget a `?view=` read goes through,
      // so an unregistered view degrades to the host's placeholder instead of
      // crashing the turn.
      AgentSurface(:final payload) => ComponentHost(
        registry: context.read<ComponentRegistry>(),
        payload: payload,
      ),
      SurfaceUnavailable(:final view, :final message) => _Bubble(
        text: 'Could not show "$view": $message',
        fromUser: false,
      ),
    };
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = AppSpacing.of(context);
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: fromUser ? colors.primaryContainer : colors.surfaceContainerHigh,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          // Verbatim. The backend wrote this text and the client never
          // rewrites, truncates or reformats it (N-9).
          child: Text(text),
        ),
      ),
    );
  }
}
