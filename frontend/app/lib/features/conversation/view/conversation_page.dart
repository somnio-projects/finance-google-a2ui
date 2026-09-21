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
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConversationBloc>(
      create: (context) => ConversationBloc(
        agentRepository: context.read<AgentRepository>(),
        viewsRepository: context.read<ViewsRepository>(),
      ),
      child: const ConversationView(),
    );
  }
}
