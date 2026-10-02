import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../repository_harness.dart';

void main() {
  group('$ViewsRepository revalidation', () {
    test('revalidates with the ETag it was served', () async {
      final harness = RepositoryHarness(
        (_) async => envelopeResponse(etag: '"e1"'),
      );
      await harness.fetch();
      await harness.fetch();
      expect(harness.sent.first.headers.containsKey('if-none-match'), isFalse);
      expect(harness.sent.last.headers['if-none-match'], equals('"e1"'));
    });

    test('resolves a 304 to the cached envelope', () async {
      // A 304 is a success and not an empty result: the caller re-renders
      // what it already holds (spec client/0003 §6).
      var calls = 0;
      final harness = RepositoryHarness((_) async {
        calls++;
        if (calls == 1) return envelopeResponse(etag: '"e1"');
        return http.Response(
          '',
          304,
          headers: <String, String>{'etag': '"e1"'},
        );
      });
      final first = await harness.fetch();
      final second = await harness.fetch();
      expect(second, equals(first));
      expect((second as Ok<RenderedViews>).value.views, isNotEmpty);
    });

    test(
      'reports a 304 with nothing cached rather than an empty view',
      () async {
        final harness = RepositoryHarness((_) async => http.Response('', 304));
        final result = await harness.fetch();
        expect((result as Err<RenderedViews>).failure, isA<ContractFailure>());
      },
    );

    test('keys the cache on the options, not only the view ids', () async {
      final harness = RepositoryHarness(
        (_) async => envelopeResponse(etag: '"e1"'),
      );
      await harness.fetch(options: <String, String>{'top_n': '2'});
      await harness.fetch(options: <String, String>{'top_n': '5'});
      expect(harness.sent.last.headers.containsKey('if-none-match'), isFalse);
    });

    test('treats two spellings of the same options as one entry', () async {
      final harness = RepositoryHarness(
        (_) async => envelopeResponse(etag: '"e1"'),
      );
      await harness.fetch(
        options: <String, String>{'top_n': '2', 'precision': '2'},
      );
      await harness.fetch(
        options: <String, String>{'precision': '2', 'top_n': '2'},
      );
      expect(harness.sent.last.headers['if-none-match'], equals('"e1"'));
    });

    test('evicts the oldest entry rather than growing without bound', () async {
      // The cache is ETag bookkeeping, not a store. Past the cap the oldest
      // entry goes, so the very first request has to be re-fetched in full.
      final harness = RepositoryHarness(
        (_) async => envelopeResponse(etag: '"e1"'),
      );
      for (var i = 0; i <= ViewsRepository.maxCachedEnvelopes; i++) {
        await harness.fetch(options: <String, String>{'top_n': '$i'});
      }
      await harness.fetch(options: <String, String>{'top_n': '0'});
      expect(harness.sent.last.headers.containsKey('if-none-match'), isFalse);
    });
  });

  group('$ViewsRepository clearCache', () {
    test('drops the ETags so a later read re-fetches in full', () async {
      // A cached portfolio must not outlive the credential allowed to read it.
      final harness = RepositoryHarness(
        (_) async => envelopeResponse(etag: '"e1"'),
      );
      await harness.fetch();
      harness.repository.clearCache();
      await harness.fetch();
      expect(harness.sent.last.headers.containsKey('if-none-match'), isFalse);
    });
  });
}
