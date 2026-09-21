import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/view/conversation_transcript.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The conversation surface: the user types, the turn runs, surfaces appear.
class ConversationView extends StatefulWidget {
  /// Creates the view.
  const ConversationView({super.key});

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ConversationBloc>().add(ConversationMessageSent(text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask the agent')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: BlocBuilder<ConversationBloc, ConversationState>(
              builder: (context, state) =>
                  ConversationTranscript(entries: state.entries),
            ),
          ),
          const _TurnStatus(),
          _Composer(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

/// Shows that a turn is running, or why the last one failed.
class _TurnStatus extends StatelessWidget {
  const _TurnStatus();

  @override
  Widget build(BuildContext context) {
    final spacing = AppSpacing.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<ConversationBloc, ConversationState>(
      builder: (context, state) => switch (state.status) {
        ConversationStatus.idle => const SizedBox.shrink(),
        ConversationStatus.running => Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: const LinearProgressIndicator(),
        ),
        // The backend's own safe code and detail, shown verbatim — never a
        // library message and never a stack trace.
        ConversationStatus.failed => Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            children: <Widget>[
              Text(
                state.failure?.message ?? 'The turn failed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              Text(
                state.failure?.code ?? 'unknown',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final spacing = AppSpacing.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'What moved my portfolio this month?',
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}
