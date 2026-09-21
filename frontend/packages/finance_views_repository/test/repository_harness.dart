import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

/// A repository wired to a scripted transport, plus the requests it made.
///
/// Shared by the fetch suite and the caching suite so both drive the same
/// construction.
class RepositoryHarness {
  /// Builds a repository whose transport answers with [handler].
  RepositoryHarness(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    repository = ViewsRepository(
      apiClient: FinanceApiClient(
        baseUrl: Uri.parse('http://localhost:8000'),
        tokenProvider: anonymousToken,
        httpClient: MockClient((request) {
          sent.add(request);
          return handler(request);
        }),
      ),
    );
  }

  /// Every request the transport saw, in order.
  final List<http.Request> sent = <http.Request>[];

  /// The repository under test.
  late final ViewsRepository repository;

  /// Asks for the one view the fixture carries.
  Future<Result<RenderedViews>> fetch({
    Map<String, String> options = const <String, String>{},
  }) => repository.fetchPortfolioViews(
    portfolioId: 'current',
    views: <String>['holdings.allocation.v1'],
    options: options,
  );
}

/// A 200 answer carrying the fixture envelope.
http.Response envelopeResponse({String? etag}) => http.Response(
  jsonEncode(renderedViewsEnvelope()),
  200,
  headers: <String, String>{'content-type': 'application/json', 'etag': ?etag},
);
