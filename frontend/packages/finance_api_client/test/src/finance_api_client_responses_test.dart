import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../client_harness.dart';

void main() {
  group('$FinanceApiClient response decoding', () {
    test('decodes a 200 body and surfaces the ETag', () async {
      final harness = ClientHarness(
        (_) async => jsonOk(
          <String, dynamic>{'portfolio_id': 'current'},
          headers: <String, String>{'etag': '"de120f2"'},
        ),
      );
      final result = await harness.client.getJson(
        '/v1/portfolios/current/views',
      );
      final value = (result as Ok<JsonResponse>).value;
      expect(value.statusCode, equals(200));
      expect(value.etag, equals('"de120f2"'));
      expect(value.body, equals(<String, dynamic>{'portfolio_id': 'current'}));
    });

    test('reports a 304 as a success with no body', () async {
      final harness = ClientHarness(
        (_) async => http.Response(
          '',
          304,
          headers: <String, String>{'etag': '"de120f2"'},
        ),
      );
      final result = await harness.client.getJson('/v1/views');
      final value = (result as Ok<JsonResponse>).value;
      expect(value.isNotModified, isTrue);
      expect(value.body, isNull);
      expect(value.etag, equals('"de120f2"'));
    });

    test('turns a problem document into a $ProblemFailure', () async {
      final harness = ClientHarness(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'type': 'https://errors.finance-a2ui/validation-failed',
            'title': 'Unprocessable Entity',
            'status': 422,
            'detail': "view 'x' rejected option(s) ['top_n']",
          }),
          422,
          headers: <String, String>{'content-type': 'application/problem+json'},
        ),
      );
      final result = await harness.client.getJson(
        '/v1/portfolios/current/views',
      );
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<ProblemFailure>());
      expect(failure.code, equals('validation-failed'));
    });

    test('reports a non-problem error body as a transport failure', () async {
      // A gateway, a proxy or a load balancer answered. Inventing a problem
      // document the backend never sent would be worse than saying so.
      final harness = ClientHarness(
        (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
      );
      final result = await harness.client.getJson('/v1/views');
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('the server answered 502'));
    });

    test('reports an unreadable 200 body as a contract failure', () async {
      final harness = ClientHarness(
        (_) async => http.Response('not json', 200),
      );
      final result = await harness.client.getJson('/v1/views');
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<ContractFailure>());
      expect(failure.message, contains('/v1/views'));
    });

    test('reports an empty 200 body as a contract failure', () async {
      final harness = ClientHarness((_) async => http.Response('', 200));
      final result = await harness.client.getJson('/v1/views');
      expect((result as Err<JsonResponse>).failure, isA<ContractFailure>());
    });

    test('turns a socket error into a $TransportFailure', () async {
      final harness = ClientHarness(
        (_) async => throw http.ClientException('connection refused'),
      );
      final result = await harness.client.getJson('/v1/views');
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('connection refused'));
    });

    test('turns a timeout into a $TransportFailure', () async {
      final harness = ClientHarness(
        (_) async => throw TimeoutException('slow'),
      );
      final result = await harness.client.getJson('/v1/views');
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('the request timed out'));
    });
  });
}
