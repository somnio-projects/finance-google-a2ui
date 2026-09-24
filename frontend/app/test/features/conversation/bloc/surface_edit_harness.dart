/// The seed and the stubs `conversation_surface_edit_test.dart` and
/// `conversation_surface_edit_races_test.dart` share (spec frontend/0026).
///
/// Extracted so both stay inside the 150-line budget — the remedy
/// `.claude/rules/frontend/testing.md` §3 prescribes.
library;

import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

import 'conversation_harness.dart';

/// The view every fixture here renders.
const String editedView = exampleView;

/// A surface as the agent left it: rendered with one option.
const AgentSurface initialSurface = AgentSurface(
  ViewPayload(editedView, <String, dynamic>{
    'view': editedView,
    'title': 'before',
  }),
  options: <String, String>{'top_n': '5'},
);

/// A transcript with one question and one surface, at slot 1.
const ConversationState editSeed = ConversationState(
  entries: <ConversationEntry>[UserSaid('what moved?'), initialSurface],
);

/// A bloc over [views] whose agent emits nothing; the seed is applied by the
/// caller so each case reads what it starts from.
ConversationBloc editBloc(MockViewsRepository views) =>
    buildBloc(events: const <AgentEvent>[], views: views);
