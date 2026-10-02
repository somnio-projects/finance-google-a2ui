import 'dart:convert';

import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../repository_harness.dart';

/// Answers with an envelope carrying exactly the ids the request asked for,
/// so a merge can be asserted rather than assumed.
http.Response echoEnvelope(http.Request request) {
  final requested = request.url.queryParametersAll['view'] ?? <String>[];
  return http.Response(
    jsonEncode(<String, dynamic>{
      'as_of': '2026-09-20T00:00:00Z',
      'portfolio_id': 'current',
      'views': <String, dynamic>{
        for (final id in requested) id: <String, dynamic>{'view': id},
      },
    }),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

/// A harness whose transport echoes back whatever was asked for.
RepositoryHarness echoHarness() =>
    RepositoryHarness((request) async => echoEnvelope(request));

/// [count] distinct, well-shaped view ids, in a stable order.
List<String> ids(int count) =>
    List<String>.generate(count, (i) => 'view.sample.v$i');

void main() {
  group('$ViewsRepository fetchAllPortfolioViews', () {
    test('makes one request when the ids fit in one', () async {
      final harness = echoHarness();
      final result = await harness.repository.fetchAllPortfolioViews(
        portfolioId: 'current',
        views: ids(ViewsRepository.maxViewsPerRequest),
      );
      expect((result as Ok<RenderedViews>).value.views, hasLength(4));
      expect(harness.sent, hasLength(1));
    });

    test('splits the request once the registry outgrows the cap', () async {
      // The cap is reached by *adding a component*, which is the edit the
      // component seam promises never to require. Five ids, two requests.
      final harness = echoHarness();
      final result = await harness.repository.fetchAllPortfolioViews(
        portfolioId: 'current',
        views: ids(5),
      );
      final value = (result as Ok<RenderedViews>).value;
      expect(value.views.keys, equals(ids(5)));
      expect(harness.sent, hasLength(2));
      expect(
        harness.sent.first.url.queryParametersAll['view'],
        equals(ids(5).sublist(0, 4)),
      );
      expect(
        harness.sent.last.url.queryParametersAll['view'],
        equals(<String>['view.sample.v4']),
      );
    });

    test('carries the envelope fields and drops the merged ETag', () async {
      final harness = echoHarness();
      final result = await harness.repository.fetchAllPortfolioViews(
        portfolioId: 'current',
        views: ids(5),
      );
      final value = (result as Ok<RenderedViews>).value;
      expect(value.asOf, equals('2026-09-20T00:00:00Z'));
      expect(value.portfolioId, equals('current'));
      // No single tag identifies a body assembled from several responses.
      expect(value.etag, isNull);
    });

    test('returns the first failure and stops', () async {
      var call = 0;
      final harness = RepositoryHarness((request) async {
        call++;
        if (call == 1) return echoEnvelope(request);
        return http.Response('gateway exploded', 502);
      });
      final result = await harness.repository.fetchAllPortfolioViews(
        portfolioId: 'current',
        views: ids(5),
      );
      expect((result as Err<RenderedViews>).failure, isA<TransportFailure>());
      expect(harness.sent, hasLength(2));
    });

    test('fails on the first chunk without asking for the rest', () async {
      final harness = RepositoryHarness(
        (_) async => http.Response('gateway exploded', 502),
      );
      final result = await harness.repository.fetchAllPortfolioViews(
        portfolioId: 'current',
        views: ids(9),
      );
      expect((result as Err<RenderedViews>).failure, isA<TransportFailure>());
      expect(harness.sent, hasLength(1));
    });

    test('delegates an empty list to the single-request bound', () async {
      // Unchanged behaviour: still a caller error, still refused before a
      // round trip is spent on a guaranteed 422.
      final harness = echoHarness();
      final result = await harness.repository.fetchAllPortfolioViews(
        portfolioId: 'current',
        views: <String>[],
      );
      expect((result as Err<RenderedViews>).failure, isA<ContractFailure>());
      expect(harness.sent, isEmpty);
    });
  });
}
