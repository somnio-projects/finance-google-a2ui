import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/rendered_views.dart';
import 'package:finance_views_repository/src/view_chunks.dart';
import 'package:finance_views_repository/src/view_payload.dart';
import 'package:finance_views_repository/src/views_repository.dart';

/// Reading more view ids than one request may carry.
///
/// An extension rather than a method on [ViewsRepository] so that class stays
/// inside the 150-line budget, and so the single-request primitive keeps its
/// bound intact: `fetchPortfolioViews` still refuses more than
/// [ViewsRepository.maxViewsPerRequest] ids, because sending more is a
/// guaranteed 422 and failing before the round trip is the cheaper answer.
extension BatchedViewReads on ViewsRepository {
  /// Fetches **every** id in [views], across as many requests as it takes.
  ///
  /// The read endpoint caps one request at [ViewsRepository.maxViewsPerRequest]
  /// ids, so a build registering a fifth component could not ask for them all
  /// at once — the cap was reached by *adding a component*, which is exactly
  /// the kind of edit the component seam promises never to require.
  ///
  /// This is not a client-side filter or a re-rank: every id is requested, in
  /// the order given, and the envelopes are merged (N-10 untouched). The
  /// first failure wins — the read endpoint is all-or-nothing per request, so
  /// reporting a half-filled screen as success would invent a status the
  /// backend never sent.
  ///
  /// The merged envelope carries **no `ETag`**: no single tag identifies a
  /// body assembled from several responses. Each chunk keeps its own tag
  /// inside the repository's cache, so revalidation still works per chunk.
  Future<Result<RenderedViews>> fetchAllPortfolioViews({
    required String portfolioId,
    required List<String> views,
    Map<String, String> options = const <String, String>{},
  }) async {
    final chunks = chunkViewIds(views, ViewsRepository.maxViewsPerRequest);
    if (chunks.length <= 1) {
      // One chunk, or none: delegate unchanged so the single-request path
      // keeps its cache entry, its `ETag` and its empty-list failure.
      return fetchPortfolioViews(
        portfolioId: portfolioId,
        views: views,
        options: options,
      );
    }
    final head = await fetchPortfolioViews(
      portfolioId: portfolioId,
      views: chunks.first,
      options: options,
    );
    if (head case Err<RenderedViews>()) return head;
    final first = (head as Ok<RenderedViews>).value;
    final merged = <String, ViewPayload>{...first.views};
    for (final chunk in chunks.skip(1)) {
      final result = await fetchPortfolioViews(
        portfolioId: portfolioId,
        views: chunk,
        options: options,
      );
      if (result case Err<RenderedViews>()) return result;
      merged.addAll((result as Ok<RenderedViews>).value.views);
    }
    return Ok<RenderedViews>(
      RenderedViews(
        asOf: first.asOf,
        portfolioId: first.portfolioId,
        views: merged,
        etag: null,
      ),
    );
  }
}
