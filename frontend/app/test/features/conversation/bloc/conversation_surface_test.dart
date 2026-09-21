import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'conversation_harness.dart';

/// Runs one turn and returns the entries it produced.
Future<List<ConversationEntry>> entriesAfterTurn(ConversationBloc bloc) async {
  bloc.add(const ConversationMessageSent('what moved?'));
  await bloc.stream.firstWhere(
    (state) => state.entries.length > 1 || state.failure != null,
  );
  final entries = bloc.state.entries;
  await bloc.close();
  return entries;
}

void main() {
  group('$ConversationBloc render intents', () {
    test('resolves the view the agent chose, with its options', () async {
      // N-6/N-7: the id and the options are the agent's, taken from the
      // registry, and they travel to the same read endpoint a `?view=`
      // request uses. The client invents neither.
      final views = MockViewsRepository();
      final bloc = buildBloc(
        events: const <AgentEvent>[exampleSurface],
        views: views,
      );
      await entriesAfterTurn(bloc);

      final captured = verify(
        () => views.fetchPortfolioViews(
          portfolioId: 'current',
          views: captureAny(named: 'views'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured.first, equals(<String>[exampleView]));
      expect(captured.last, equals(<String, String>{'top_n': '5'}));
    });

    test('shows the surface once its payload arrives', () async {
      final entries = await entriesAfterTurn(
        buildBloc(events: const <AgentEvent>[exampleSurface]),
      );
      final surface = entries.last as AgentSurface;
      expect(surface.payload.view, equals(exampleView));
      // Compared, not just cast: an entry's equality is what a rebuilt state
      // is diffed by, and it is the only thing that exercises its `props`.
      expect(surface, equals(AgentSurface(surface.payload)));
    });

    test('degrades one surface without losing the turn', () async {
      // A read that fails takes that widget down and nothing else: the answer
      // text is still worth reading.
      final entries = await entriesAfterTurn(
        buildBloc(
          events: const <AgentEvent>[exampleSurface],
          viewsResult: const Err<RenderedViews>(
            TransportFailure('the server could not be reached'),
          ),
        ),
      );
      expect(
        entries.last,
        equals(
          const SurfaceUnavailable(
            view: exampleView,
            message: 'the server could not be reached',
          ),
        ),
      );
    });

    test('reports an envelope that carries no payload for the view', () async {
      // The read succeeded and the view is missing from it — a contract
      // problem worth showing rather than a blank space.
      final entries = await entriesAfterTurn(
        buildBloc(
          events: const <AgentEvent>[
            AgentSurfaceReady(
              index: 0,
              view: 'payoff.curve.v1',
              options: <String, String>{},
            ),
          ],
        ),
      );
      final entry = entries.last as SurfaceUnavailable;
      expect(entry.view, equals('payoff.curve.v1'));
      expect(entry.message, contains('no payload'));
    });
  });
}
