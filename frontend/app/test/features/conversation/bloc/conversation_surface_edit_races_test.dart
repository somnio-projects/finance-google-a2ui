import 'dart:async';

import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';
import 'surface_edit_harness.dart';

/// GGU-113 AC-5, split from `conversation_surface_edit_test.dart` under the
/// 150-line budget: the answers that must NOT change the transcript.
void main() {
  group('$ConversationBloc editing a surface, the edges', () {
    test('an answer without the view is a refusal, not a blank', () async {
      final views = MockViewsRepository();
      final subject = editBloc(views)..emit(editSeed);
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(
          RenderedViews.fromJson(const <String, dynamic>{
            'as_of': 'x',
            'portfolio_id': 'current',
            'views': <String, dynamic>{},
          }),
        ),
      );
      subject.add(
        const ConversationSurfaceEdited(slot: 1, option: 'top_n', value: '3'),
      );
      await subject.stream.first;
      final done = await subject.stream.first;
      expect((done.entries[1] as AgentSurface).rejection, isNotNull);
      expect((done.entries[1] as AgentSurface).payload.text('title'), 'before');
      await subject.close();
    });

    test('a slow answer never overwrites a newer edit', () async {
      final views = MockViewsRepository();
      final first = Completer<Result<RenderedViews>>();
      final second = Completer<Result<RenderedViews>>();
      final answers = <Completer<Result<RenderedViews>>>[first, second];
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => answers.removeAt(0).future);
      final subject = editBloc(views)
        ..emit(editSeed)
        ..add(
          const ConversationSurfaceEdited(slot: 1, option: 'top_n', value: '3'),
        )
        ..add(
          const ConversationSurfaceEdited(slot: 1, option: 'top_n', value: '4'),
        );
      await subject.stream.first;
      await subject.stream.first;
      second.complete(Ok<RenderedViews>(renderedViews()));
      final done = await subject.stream.first;
      first.complete(
        const Err<RenderedViews>(TransportFailure('too late to matter')),
      );
      await Future<void>.delayed(Duration.zero);
      expect((done.entries[1] as AgentSurface).options, const <String, String>{
        'top_n': '4',
      });
      expect((subject.state.entries[1] as AgentSurface).rejection, isNull);
      await subject.close();
    });

    test('an index that is not a surface is ignored', () async {
      final views = MockViewsRepository();
      final subject = editBloc(views)
        ..emit(editSeed)
        ..add(const ConversationSurfaceEdited(slot: 0, option: 'x', value: 'y'))
        ..add(
          const ConversationSurfaceEdited(slot: 9, option: 'x', value: 'y'),
        );
      await Future<void>.delayed(Duration.zero);
      expect(subject.state, editSeed);
      verifyNever(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      );
      await subject.close();
    });
  });
}
