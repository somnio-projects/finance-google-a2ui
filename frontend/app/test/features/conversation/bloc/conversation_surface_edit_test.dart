import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';
import 'surface_edit_harness.dart';

/// GGU-113: an edit of a surface's declared option re-requests that one view
/// with the option changed, and the transcript keeps its order (ADR-K D-11).
void main() {
  const view = editedView;
  final payload = renderedViews().views.values.single;

  group('$ConversationBloc editing a surface', () {
    test(
      're-requests the view with the option merged and replaces the slot',
      () async {
        final views = MockViewsRepository();
        final subject = editBloc(views)
          ..emit(editSeed)
          ..add(
            const ConversationSurfaceEdited(
              slot: 1,
              option: 'top_n',
              value: '3',
            ),
          );
        // First the option is marked in flight, then the new payload lands.
        final pending = await subject.stream.first;
        expect(
          pending.entries[1],
          const AgentSurface(
            ViewPayload(view, <String, dynamic>{
              'view': view,
              'title': 'before',
            }),
            // The merged intent is written on the edit itself (OD-3).
            options: <String, String>{'top_n': '3'},
            pendingOption: 'top_n',
          ),
        );
        final done = await subject.stream.first;
        expect(
          done.entries[1],
          AgentSurface(payload, options: const <String, String>{'top_n': '3'}),
        );
        expect(done.entries.first, const UserSaid('what moved?'));
        verify(
          () => views.fetchPortfolioViews(
            portfolioId: 'current',
            views: <String>[view],
            options: <String, String>{'top_n': '3'},
          ),
        ).called(1);
        await subject.close();
      },
    );

    test(
      'a refused edit keeps the payload and shows the sentence (AC-3)',
      () async {
        final views = MockViewsRepository();
        final subject = editBloc(views)..emit(editSeed);
        when(
          () => views.fetchPortfolioViews(
            portfolioId: any(named: 'portfolioId'),
            views: any(named: 'views'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Err<RenderedViews>(
            ProblemFailure(
              ProblemDetails.tryParse(<String, dynamic>{
                'type': 'https://errors.finance-a2ui/validation-error',
                'title': 'Unprocessable',
                'status': 422,
                'detail': 'size must be a positive number',
              })!,
            ),
          ),
        );
        subject.add(
          const ConversationSurfaceEdited(slot: 1, option: 'size', value: '-1'),
        );
        await subject.stream.first;
        final done = await subject.stream.first;
        expect(
          done.entries[1],
          const AgentSurface(
            ViewPayload(view, <String, dynamic>{
              'view': view,
              'title': 'before',
            }),
            options: <String, String>{'top_n': '5'},
            rejection: 'size must be a positive number',
          ),
        );
        await subject.close();
      },
    );
  });
}
