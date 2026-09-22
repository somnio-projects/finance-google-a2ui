import 'dart:async';

import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/bloc/voice_input_bloc.dart';
import 'package:finance_app/features/conversation/view/conversation_view.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

/// The screen that runs agent turns.
///
/// The page/view split again: this file owns the bloc's lifetime and is
/// therefore the only one in the feature allowed to read a repository from
/// the tree (`layering_test.dart::only a page resolves a repository from the
/// widget tree`).
///
/// **Stateful, and that is the fix for a reported dead end.** The question a
/// chip carries used to be sent inside `BlocProvider.create`. The Assistant
/// is a branch of a `StatefulShellRoute`, which keeps each branch's
/// navigator alive: the second time a reader tapped a chip the branch was
/// restored, this element was reused, `create` did not run, and the tap
/// "opened the Assistant and did nothing" (spec frontend/0021 OD-2). The
/// bloc now lives in the state and the question is dispatched whenever the
/// route brings a new one.
class ConversationPage extends StatefulWidget {
  /// Creates the page.
  const ConversationPage({this.initialQuestion, super.key});

  /// A question to send as soon as the route carries one — the Home chips
  /// and the Holdings hand-off arrive with one; the tab itself arrives with
  /// none.
  final String? initialQuestion;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  ConversationBloc? _bloc;
  VoiceInputBloc? _voice;

  ConversationBloc get _conversation => _bloc ??= ConversationBloc(
    agentRepository: context.read<AgentRepository>(),
    viewsRepository: context.read<ViewsRepository>(),
  );

  /// The dictation bloc, built here for the same reason the conversation's
  /// is: this is the page, so this is where a bloc's lifetime and the seam it
  /// needs are resolved (spec frontend/0023 OD-2).
  VoiceInputBloc get _voiceInput =>
      _voice ??= VoiceInputBloc(recognizer: context.read<SpeechRecognizer>());

  @override
  void initState() {
    super.initState();
    // After the first frame: `context.read` needs the providers above, and
    // the bloc must exist before an event reaches it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ask(widget.initialQuestion),
    );
  }

  @override
  void didUpdateWidget(ConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tab's own button carries no question and must not replay the last
    // chip's; a chip carrying the same question the page already asked
    // produces no navigation at all, so there is nothing to react to — both
    // are covered by comparing with what arrived before.
    if (widget.initialQuestion != oldWidget.initialQuestion) {
      _ask(widget.initialQuestion);
    }
  }

  void _ask(String? question) {
    if (question == null || question.isEmpty) return;
    _conversation.add(ConversationMessageSent(question));
  }

  @override
  void dispose() {
    // The bloc's own close is a Future nobody awaits: `dispose` is
    // synchronous by contract and the element is going away regardless.
    unawaited(_bloc?.close() ?? Future<void>.value());
    unawaited(_voice?.close() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConversationBloc>.value(value: _conversation),
        BlocProvider<VoiceInputBloc>.value(value: _voiceInput),
      ],
      // A surface's tap becomes a turn through the one bloc that owns the
      // conversation (spec frontend/0011 OD-4).
      child: Builder(
        builder: (context) => SurfaceActions(
          onAction: (request) => context.read<ConversationBloc>().add(
            ConversationActionSent(request),
          ),
          child: const ConversationView(),
        ),
      ),
    );
  }
}
