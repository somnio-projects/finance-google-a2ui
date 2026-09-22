import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/view/conversation_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The screen that runs agent turns.
///
/// The page/view split again: this file owns the bloc's lifetime and is
/// therefore the only one in the feature allowed to read a repository from
/// the tree (`layering_test.dart::only a page resolves a repository from the
/// widget tree`).
class ConversationPage extends StatelessWidget {
  /// Creates the page.
  const ConversationPage({this.initialQuestion, super.key});

  /// A question to send as soon as the page opens — the Home chips and the
  /// Holdings hand-off arrive with one; the tab itself arrives with none.
  final String? initialQuestion;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConversationBloc>(
      create: (context) {
        final bloc = ConversationBloc(
          agentRepository: context.read<AgentRepository>(),
          viewsRepository: context.read<ViewsRepository>(),
        );
        final question = initialQuestion;
        if (question != null && question.isNotEmpty) {
          bloc.add(ConversationMessageSent(question));
        }
        return bloc;
      },
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
