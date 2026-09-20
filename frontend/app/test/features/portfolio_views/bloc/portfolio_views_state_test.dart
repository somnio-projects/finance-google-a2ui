import 'package:finance_app/features/portfolio_views/bloc/portfolio_views_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group(PortfolioViewsState, () {
    PortfolioViewsState createSubject({
      PortfolioViewsStatus status = PortfolioViewsStatus.initial,
      RenderedViews? rendered,
      AppFailure? failure,
    }) => PortfolioViewsState(
      status: status,
      rendered: rendered,
      failure: failure,
    );

    test('supports value equality', () {
      expect(createSubject(), equals(createSubject()));
      expect(
        createSubject(status: PortfolioViewsStatus.loading),
        isNot(equals(createSubject())),
      );
    });

    test('props are correct', () {
      final envelope = renderedViews();
      const failure = TransportFailure('offline');
      expect(
        createSubject(
          status: PortfolioViewsStatus.failure,
          rendered: envelope,
          failure: failure,
        ).props,
        equals(<Object?>[PortfolioViewsStatus.failure, envelope, failure]),
      );
    });

    group('copyWith', () {
      test('returns the same object if no arguments are provided', () {
        expect(createSubject().copyWith(), equals(createSubject()));
      });

      test('retains the old value for every parameter left out', () {
        final subject = createSubject(
          status: PortfolioViewsStatus.success,
          rendered: renderedViews(),
        );
        expect(subject.copyWith(), equals(subject));
      });

      test('replaces every supplied parameter', () {
        final envelope = renderedViews();
        expect(
          createSubject().copyWith(
            status: () => PortfolioViewsStatus.success,
            rendered: () => envelope,
          ),
          equals(
            createSubject(
              status: PortfolioViewsStatus.success,
              rendered: envelope,
            ),
          ),
        );
      });

      test('clears a nullable field when the getter returns null', () {
        // The getter form is what lets "leave it alone" and "clear it" be two
        // different calls; a plain `T?` parameter cannot express both.
        final subject = createSubject(
          status: PortfolioViewsStatus.failure,
          failure: const TransportFailure('offline'),
        );
        expect(subject.copyWith(failure: () => null).failure, isNull);
        expect(subject.copyWith().failure, isNotNull);
      });
    });
  });
}
