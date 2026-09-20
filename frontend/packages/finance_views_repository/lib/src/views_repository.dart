import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';
import 'package:finance_views_repository/src/rendered_views.dart';

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

  final FinanceApiClient _apiClient;
  final Map<String, RenderedViews> _cache = <String, RenderedViews>{};

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
    final key = _cacheKey(path, views, options);
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

  /// Forgets every cached envelope and its `ETag`.
  ///
  /// Called on sign-out: a cached portfolio must not outlive the credential
  /// that was allowed to read it.
  void clearCache() => _cache.clear();

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
      _cache[key] = envelope;
      return Ok<RenderedViews>(envelope);
    } on PayloadContractException catch (error) {
      return Err<RenderedViews>(error.failure);
    }
  }

  String _cacheKey(
    String path,
    List<String> views,
    Map<String, String> options,
  ) {
    // Sorted so that the same request written two ways is one cache entry.
    final pairs =
        options.entries
            .map((option) => '${option.key}=${option.value}')
            .toList()
          ..sort();
    return '$path?${views.join(",")}&${pairs.join("&")}';
  }
}
