/// Data layer — the only code in the client that speaks HTTP.
///
/// It knows URLs, headers, status codes and RFC 9457, and it knows nothing
/// about portfolios, views or widgets. Everything above it receives decoded
/// JSON and a `Result`; nothing above it ever sees an `http.Response`.
library;

export 'src/a2a_client.dart';
export 'src/auth_token_provider.dart';
export 'src/event_stream.dart';
export 'src/finance_api_client.dart';
export 'src/json_response.dart';
