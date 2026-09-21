// Equality is the thing under test here, so the events are built with `new`
// rather than `const`: two const instances of the same shape are canonicalised
// to one object and `==` would pass without the class implementing it.
// ignore_for_file: prefer_const_constructors

import 'package:finance_app/features/portfolio_views/bloc/portfolio_views_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(PortfolioViewsEvent, () {
    group(PortfolioViewsRequested, () {
      const views = <String>['holdings.allocation.v1'];

      test('defaults to the caller own portfolio and no options', () {
        const event = PortfolioViewsRequested(views: views);
        expect(event.portfolioId, equals('current'));
        expect(event.options, isEmpty);
      });

      test('supports value equality', () {
        expect(
          PortfolioViewsRequested(views: views),
          equals(PortfolioViewsRequested(views: views)),
        );
        expect(
          PortfolioViewsRequested(views: views),
          isNot(
            equals(PortfolioViewsRequested(views: const <String>['a.b.v1'])),
          ),
        );
      });

      test('props are correct', () {
        expect(
          PortfolioViewsRequested(
            views: views,
            options: const <String, String>{'top_n': '2'},
          ).props,
          equals(<Object?>[
            views,
            'current',
            const <String, String>{'top_n': '2'},
          ]),
        );
      });
    });
  });
}
