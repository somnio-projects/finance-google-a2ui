import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';
import 'package:finance_views_repository/src/rendered_views.dart';
import 'package:finance_views_repository/src/view_cache_key.dart';
import 'package:finance_views_repository/src/view_catalog.dart';

/// Reads rendered projections for a portfolio.
///
/// The client asks for views **by id** and never constructs one (N-6), and
/// sends only options the view's own schema declares (N-7) — enforcing that
/// bound is the caller's job, because the schema lives in the catalog.
class ViewsRepository {
  /// Creates a repository over [apiClient].
  ViewsRepository({required FinanceApiClient apiClient})
    : _apiClient = apiClient;

  /// Most views the read endpoint accepts in one request (`MAX_VIEWS`).
  static const int maxViewsPerRequest = 4;

  /// Most envelopes kept for revalidation.
  ///
  /// Small and bounded on purpose: this is `ETag` bookkeeping, not a
  /// store. Uncapped it would grow for the life of the app, which is a
  /// leak dressed as a cache.
  static const int maxCachedEnvelopes = 16;

  final FinanceApiClient _apiClient;
  final Map<String, RenderedViews> _cache = <String, RenderedViews>{};
  ViewCatalog? _catalog;

  /// Fetches [views] for [portfolioId], revalidating a cached copy when one
  /// is held.
  ///
  /// A 304 resolves to the cached envelope: it means "unchanged", which is a
  /// success and not an empty result (§6). Asking for more than
  /// [maxViewsPerRequest] ids is a caller error and fails before any request
  /// is made, rather than spending a round trip on a guaranteed 422.
  Future<Result<RenderedViews>> fetchPortfolioViews({
    required String portfolioId,
    required List<String> views,
    Map<String, String> options = const <String, String>{},
  }) async {
    if (views.isEmpty || views.length > maxViewsPerRequest) {
      return Err<RenderedViews>(
        ContractFailure(
          'view',
          'between 1 and $maxViewsPerRequest view ids, got ${views.length}',
        ),
      );
    }
    final path = '/v1/portfolios/$portfolioId/views';
    final key = viewCacheKey(path, views, options);
    final cached = _cache[key];
    final result = await _apiClient.getJson(
      path,
      query: <String, List<String>>{
        'view': views,
        for (final option in options.entries)
          option.key: <String>[option.value],
      },
      ifNoneMatch: cached?.etag,
    );
    return switch (result) {
      Err<JsonResponse>(:final failure) => Err<RenderedViews>(failure),
      Ok<JsonResponse>(:final value) => _envelope(value, key, cached),
    };
  }

  /// Fetches the catalog of every view the backend can render.
  ///
  /// The catalog describes shapes, never portfolio data, but it is served
  /// behind the same credential and revalidated the same way: a 304 resolves
  /// to the cached catalog, which is a success and not an empty result.
  Future<Result<ViewCatalog>> fetchCatalog() async {
    final cached = _catalog;
    final result = await _apiClient.getJson(
      '/v1/views',
      ifNoneMatch: cached?.etag,
    );
    return switch (result) {
      Err<JsonResponse>(:final failure) => Err<ViewCatalog>(failure),
      Ok<JsonResponse>(:final value) => _catalogOf(value, cached),
    };
  }

  /// Forgets every cached envelope, the catalog, and their `ETag`s.
  ///
  /// Called on sign-out: a cached portfolio must not outlive the credential
  /// that was allowed to read it.
  void clearCache() {
    _cache.clear();
    _catalog = null;
  }

  Result<ViewCatalog> _catalogOf(JsonResponse response, ViewCatalog? cached) {
    if (response.isNotModified) {
      if (cached != null) return Ok<ViewCatalog>(cached);
      return const Err<ViewCatalog>(
        ContractFailure('<response>', 'a body, since nothing was cached'),
      );
    }
    try {
      final catalog = ViewCatalog.fromJson(response.body, etag: response.etag);
      _catalog = catalog;
      return Ok<ViewCatalog>(catalog);
    } on PayloadContractException catch (error) {
      return Err<ViewCatalog>(error.failure);
    }
  }

  Result<RenderedViews> _envelope(
    JsonResponse response,
    String key,
    RenderedViews? cached,
  ) {
    if (response.isNotModified) {
      if (cached != null) return Ok<RenderedViews>(cached);
      // A 304 without anything cached means the request carried an
      // `If-None-Match` this repository did not issue. Reporting it is better
      // than rendering nothing and calling it success.
      return const Err<RenderedViews>(
        ContractFailure('<response>', 'a body, since nothing was cached'),
      );
    }
    try {
      final envelope = RenderedViews.fromJson(
        response.body,
        etag: response.etag,
      );
      if (_cache.length >= maxCachedEnvelopes) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = envelope;
      return Ok<RenderedViews>(envelope);
    } on PayloadContractException catch (error) {
      return Err<RenderedViews>(error.failure);
    }
  }
}
