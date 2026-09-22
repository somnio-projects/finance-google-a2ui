import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/catalog_snapshot.dart';

/// A stand-in for the repository both catalog pages read.
class MockCatalogRepository extends Mock implements ViewsRepository;

/// One served entry for [view] of the snapshot, in the `GET /v1/views` shape.
///
/// The snapshot keys an entry by `view`; the endpoint says `id`. Everything
/// else — fields, prompt, guidance, example — is the generated artefact's,
/// read rather than copied (`.claude/rules/frontend/testing.md` §5).
Map<String, dynamic> servedEntry(Map<String, dynamic> view) =>
    <String, dynamic>{...view, 'id': view['view']};

/// The whole snapshot as the catalog the backend would serve.
ViewCatalog snapshotCatalog({String? etag = '"c1"'}) => ViewCatalog.fromJson(
  <Object?>[for (final view in CatalogSnapshot.load().views) servedEntry(view)],
  etag: etag,
);

/// The served entry whose A2UI component is [component].
CatalogEntry snapshotEntry(String component) => CatalogEntry.fromJson(
  servedEntry(CatalogSnapshot.load().entryFor(component)),
);

/// Stubs `fetchCatalog` to answer [result], the snapshot by default.
void stubCatalog(
  MockCatalogRepository repository, {
  Result<ViewCatalog>? result,
}) {
  when(() => repository.fetchCatalog())
      .thenAnswer((_) async => result ?? Ok<ViewCatalog>(snapshotCatalog()));
}

/// Stubs `fetchPortfolioViews` to answer [result] for any request.
void stubViews(
  MockCatalogRepository repository, {
  required Result<RenderedViews> result,
}) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: any(named: 'views'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => result);
}

/// An envelope carrying the snapshot example of [component] under its id.
RenderedViews envelopeOf(String component) {
  final snapshot = CatalogSnapshot.load();
  return RenderedViews.fromJson(<String, dynamic>{
    'as_of': '2026-09-20T00:00:00Z',
    'portfolio_id': 'current',
    'views': <String, dynamic>{
      snapshot.viewIdFor(component): snapshot.exampleFor(component),
    },
  });
}

/// The registry every component module registered itself into.
ComponentRegistry buildRegistry() => buildComponentRegistry();
