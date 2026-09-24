import 'package:finance_api_client/finance_api_client.dart';
import 'package:test/test.dart';

import '../client_harness.dart';

void main() {
  group('$FinanceApiClient request shaping', () {
    test('resolves the path against the base URL', () async {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      await harness.client.getJson('/v1/portfolios/current/views');
      expect(harness.only.url.host, equals('localhost'));
      expect(harness.only.url.port, equals(8000));
      expect(harness.only.url.path, equals('/v1/portfolios/current/views'));
    });

    test(
      'repeats a query key so several views travel in one request',
      () async {
        final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
        await harness.client.getJson(
          '/v1/portfolios/current/views',
          query: <String, List<String>>{
            'view': <String>['holdings.allocation.v1', 'taxlots.table.v1'],
            'top_n': <String>['2'],
          },
        );
        expect(
          harness.only.url.queryParametersAll['view'],
          equals(<String>['holdings.allocation.v1', 'taxlots.table.v1']),
        );
        expect(
          harness.only.url.queryParametersAll['top_n'],
          equals(<String>['2']),
        );
      },
    );

    test('sends no query string when there are no parameters', () async {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      await harness.client.getJson('/health');
      expect(harness.only.url.hasQuery, isFalse);
    });

    test('asks for JSON', () async {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      await harness.client.getJson('/health');
      expect(harness.only.headers['accept'], equals('application/json'));
    });

    test(
      'puts the credential in the Authorization header and nowhere else',
      () async {
        final harness = ClientHarness(
          (_) async => jsonOk(<String, dynamic>{}),
          tokenProvider: () async => 'secret-token',
        );
        await harness.client.getJson(
          '/v1/me',
          query: <String, List<String>>{
            'q': <String>['x'],
          },
        );
        expect(
          harness.only.headers['authorization'],
          equals('Bearer secret-token'),
        );
        // N-14: never in a URL, a query string or anything that gets logged.
        expect(harness.only.url.toString(), isNot(contains('secret-token')));
      },
    );

    test('omits the Authorization header for an anonymous caller', () async {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      await harness.client.getJson('/health');
      expect(harness.only.headers.containsKey('authorization'), isFalse);
    });

    test('passes If-None-Match through verbatim, quotes included', () async {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      await harness.client.getJson('/v1/views', ifNoneMatch: '"de120f2"');
      expect(harness.only.headers['if-none-match'], equals('"de120f2"'));
    });

    test('omits If-None-Match when nothing is cached', () async {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      await harness.client.getJson('/v1/views');
      expect(harness.only.headers.containsKey('if-none-match'), isFalse);
    });

    test('close releases the underlying client', () {
      final harness = ClientHarness((_) async => jsonOk(<String, dynamic>{}));
      expect(harness.client.close, returnsNormally);
    });
  });
}
