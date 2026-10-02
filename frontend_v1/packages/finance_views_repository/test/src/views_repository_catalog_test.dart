import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../catalog_fixtures.dart';
import '../repository_harness.dart';

void main() {
  group('$ViewsRepository fetchCatalog', () {
    test('reads /v1/views and decodes every entry', () async {
      final harness = RepositoryHarness((_) async => catalogResponse());
      final result = await harness.repository.fetchCatalog();
      final catalog = (result as Ok<ViewCatalog>).value;
      expect(harness.sent.single.url.path, '/v1/views');
      expect(harness.sent.single.headers.containsKey('if-none-match'), isFalse);
      expect(catalog.entries.single.id, 'holdings.allocation.v1');
    });

    test(
      'revalidates with the tag and resolves a 304 to the cached copy',
      () async {
        var calls = 0;
        final harness = RepositoryHarness((_) async {
          calls++;
          return calls == 1
              ? catalogResponse(etag: '"c1"')
              : http.Response('', 304);
        });
        final first = await harness.repository.fetchCatalog();
        final second = await harness.repository.fetchCatalog();
        expect(harness.sent[1].headers['if-none-match'], '"c1"');
        expect(
          (second as Ok<ViewCatalog>).value,
          same((first as Ok<ViewCatalog>).value),
        );
      },
    );

    test('a 304 with nothing cached is a contract failure', () async {
      final harness = RepositoryHarness((_) async => http.Response('', 304));
      final result = await harness.repository.fetchCatalog();
      expect((result as Err<ViewCatalog>).failure, isA<ContractFailure>());
    });

    test('a malformed catalog is a contract failure naming the path', () async {
      final harness = RepositoryHarness(
        (_) async => catalogResponse(body: <String, dynamic>{}),
      );
      final result = await harness.repository.fetchCatalog();
      final failure = (result as Err<ViewCatalog>).failure as ContractFailure;
      expect(failure.path, '<root>');
    });

    test('passes a transport failure through unchanged', () async {
      final harness = RepositoryHarness(
        (_) async => throw http.ClientException('refused'),
      );
      final result = await harness.repository.fetchCatalog();
      expect((result as Err<ViewCatalog>).failure, isA<TransportFailure>());
    });

    test('clearCache forgets the catalog too', () async {
      final harness = RepositoryHarness(
        (_) async => catalogResponse(etag: '"c1"'),
      );
      await harness.repository.fetchCatalog();
      harness.repository.clearCache();
      await harness.repository.fetchCatalog();
      expect(harness.sent[1].headers.containsKey('if-none-match'), isFalse);
    });
  });

  group('viewCacheKey', () {
    test('names the same request the same whichever way it is written', () {
      expect(
        viewCacheKey(
          '/p',
          <String>['b', 'a'],
          <String, String>{'y': '1', 'x': '2'},
        ),
        viewCacheKey(
          '/p',
          <String>['a', 'b'],
          <String, String>{'x': '2', 'y': '1'},
        ),
      );
    });
  });
}
