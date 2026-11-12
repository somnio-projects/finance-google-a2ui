import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../client_harness.dart';

/// The backend's own 429 (`api/middleware/rate_limit.py`), header and all.
http.Response _limited(String? retryAfter) => http.Response(
  jsonEncode(<String, dynamic>{
    'type': 'https://errors.finance-a2ui/rate-limited',
    'title': 'Too Many Requests',
    'status': 429,
    'detail': 'Too many requests. Try again in a minute.',
  }),
  429,
  headers: <String, String>{
    'content-type': 'application/problem+json',
    'retry-after': ?retryAfter,
  },
);

Future<ProblemFailure> _failureFor(String? retryAfter) async {
  final harness = ClientHarness((_) async => _limited(retryAfter));
  final result = await harness.client.getJson('/v1/me/access');
  return (result as Err<JsonResponse>).failure as ProblemFailure;
}

void main() {
  group('Retry-After (GGU-159)', () {
    test('delta-seconds travel with the problem as a duration', () async {
      final failure = await _failureFor('60');
      expect(failure.code, 'rate-limited');
      expect(failure.retryAfter, const Duration(seconds: 60));
    });

    test('no header, an HTTP-date or a negative is no hint at all', () async {
      expect((await _failureFor(null)).retryAfter, isNull);
      expect(
        (await _failureFor('Wed, 21 Oct 2026 07:28:00 GMT')).retryAfter,
        isNull,
      );
      expect((await _failureFor('-5')).retryAfter, isNull);
      expect((await _failureFor('"60"')).retryAfter, isNull);
    });
  });
}
