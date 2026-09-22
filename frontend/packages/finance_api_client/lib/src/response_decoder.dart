import 'dart:convert';

import 'package:finance_api_client/src/json_response.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;

/// Turns an HTTP answer into a [Result]: 304 and no-content statuses are
/// successes, a problem document is a [ProblemFailure], anything else an
/// error is a [TransportFailure], and a 401 on an authenticated call also
/// tells [onUnauthenticated] the session is over (ADR-B D-7).
///
/// Split from `FinanceApiClient` for the line budget; it is the client's
/// decoder and nobody else's.
Result<JsonResponse> decodeJsonResponse(
  http.Response response, {
  bool authenticated = true,
  void Function()? onUnauthenticated,
}) {
  final etag = response.headers['etag'];
  if (response.statusCode == 401 && authenticated) onUnauthenticated?.call();
  if (response.statusCode == 304) {
    return Ok<JsonResponse>(
      JsonResponse(statusCode: 304, body: null, etag: etag),
    );
  }
  final body = _parseBody(response);
  if (response.statusCode >= 400) return _failure(response, body);
  // 202 and 204 carry no body by contract (an accepted access request);
  // an empty 200 is still a broken answer.
  final noContent = response.statusCode == 202 || response.statusCode == 204;
  if (body == null && !noContent) {
    // `<response>` and NOT the request path. `ContractFailure.path` is a
    // dotted path into the payload and its `message` is interpolated and
    // rendered to the user, so an HTTP path put here is shown verbatim on
    // screen. It is the same defect class as the `http.ClientException`
    // leak: a value that belongs to the transport escaping into user-facing
    // text. Inert while the only id is the constant `current`, and no longer
    // reachable at all once routing grows an account or portfolio id.
    // Nothing is lost — this client logs nothing anywhere (SECURITY.md G-7),
    // so the path had no second reader to keep it for.
    return const Err<JsonResponse>(
      ContractFailure('<response>', 'a JSON body'),
    );
  }
  return Ok<JsonResponse>(
    JsonResponse(statusCode: response.statusCode, body: body, etag: etag),
  );
}

Object? _parseBody(http.Response response) {
  if (response.bodyBytes.isEmpty) return null;
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    return null;
  }
}

Err<JsonResponse> _failure(http.Response response, Object? body) {
  final problem = ProblemDetails.tryParse(body);
  if (problem != null) return Err<JsonResponse>(ProblemFailure(problem));
  // Not a problem document: a proxy, a load balancer or a gateway answered.
  // Reporting it as a transport failure is honest; inventing a problem
  // document the backend never sent would not be.
  return Err<JsonResponse>(
    TransportFailure('the server answered ${response.statusCode}'),
  );
}
