import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/view/assistant_chips.dart';
import 'package:finance_app/features/conversation/view/assistant_composer.dart';
import 'package:finance_app/features/conversation/view/assistant_header.dart';
import 'package:finance_app/features/conversation/view/conversation_transcript.dart';
import 'package:finance_app/features/conversation/view/voice_input_listener.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Assistant tab as the three flows frame it (spec frontend/0011):
/// header · transcript · follow-up chips · composer. Reads bloc state only.
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
    final tokens = HomeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.page,
      body: BlocBuilder<ConversationBloc, ConversationState>(
        builder: (context, state) {
          final running = state.status == ConversationStatus.running;
          return Column(
            children: <Widget>[
              const AssistantHeader(),
              Expanded(
                child: ConversationTranscript(
                  entries: state.entries,
                  streaming: running,
                ),
              ),
              if (state.status == ConversationStatus.failed)
                _Failure(failure: state.failure),
              SuggestionChips(
                suggestions: state.suggestions,
                onTap: (chip) => context.read<ConversationBloc>().add(
                  ConversationSuggestionTapped(chip),
                ),
              ),
              // Dictation fills the field this composer already owns; it
              // never sends (spec frontend/0022 OD-1), so the wrapper is a
              // listener over the same controller rather than a second
              // path into the agent.
              VoiceInputListener(
                controller: _controller,
                child: AssistantComposer(
                  controller: _controller,
                  onSend: _send,
                  enabled: !running,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Why the last turn failed: the backend's own safe code and detail, shown
/// verbatim — never a library message and never a stack trace.
class _Failure extends StatelessWidget {
  const _Failure({required this.failure});

  final AgentFailed? failure;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
      child: Column(
        children: <Widget>[
          Text(
            failure?.message ?? 'The turn failed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.loss),
          ),
          Text(
            failure?.code ?? 'unknown',
            style: TextStyle(fontSize: 11, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}
