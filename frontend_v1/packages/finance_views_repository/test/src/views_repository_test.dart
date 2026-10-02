import 'dart:convert';

import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../repository_harness.dart';

void main() {
  group('$ViewsRepository fetchPortfolioViews', () {
    test('requests the ids it was given and decodes the envelope', () async {
      final harness = RepositoryHarness((_) async => envelopeResponse());
      final result = await harness.fetch();
      final value = (result as Ok<RenderedViews>).value;
      expect(value.portfolioId, equals('current'));
      expect(
        harness.sent.single.url.path,
        equals('/v1/portfolios/current/views'),
      );
      expect(
        harness.sent.single.url.queryParametersAll['view'],
        equals(<String>['holdings.allocation.v1']),
      );
    });

    test('sends declared options alongside the view ids', () async {
      final harness = RepositoryHarness((_) async => envelopeResponse());
      await harness.fetch(options: <String, String>{'top_n': '2'});
      expect(
        harness.sent.single.url.queryParametersAll['top_n'],
        equals(<String>['2']),
      );
    });

    test('rejects an empty view list before spending a request', () async {
      final harness = RepositoryHarness((_) async => envelopeResponse());
      final result = await harness.repository.fetchPortfolioViews(
        portfolioId: 'current',
        views: <String>[],
      );
      expect((result as Err<RenderedViews>).failure, isA<ContractFailure>());
      expect(harness.sent, isEmpty);
    });

    test('rejects more ids than the endpoint accepts', () async {
      final harness = RepositoryHarness((_) async => envelopeResponse());
      final result = await harness.repository.fetchPortfolioViews(
        portfolioId: 'current',
        views: List<String>.generate(
          ViewsRepository.maxViewsPerRequest + 1,
          (i) => 'a.b.v$i',
        ),
      );
      expect((result as Err<RenderedViews>).failure, isA<ContractFailure>());
      expect(harness.sent, isEmpty);
    });

    test('passes a transport failure through unchanged', () async {
      final harness = RepositoryHarness(
        (_) async => throw http.ClientException('refused'),
      );
      final result = await harness.fetch();
      expect((result as Err<RenderedViews>).failure, isA<TransportFailure>());
    });

    test('turns a malformed envelope into a contract failure', () async {
      final harness = RepositoryHarness(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'portfolio_id': 'current'}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      final result = await harness.fetch();
      final failure = (result as Err<RenderedViews>).failure;
      expect(failure, isA<ContractFailure>());
      expect((failure as ContractFailure).path, equals('as_of'));
    });
  });
}
