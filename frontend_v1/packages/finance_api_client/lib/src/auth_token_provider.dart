/// Supplies the bearer credential for a single request, or `null` when the
/// caller is anonymous.
///
/// It is a function, not a class, so that the transport depends on *obtaining
/// a token* and not on how the token is obtained. Today the composition root
/// binds it to a constant read from `--dart-define`; when a real identity
/// provider lands it binds to a force-refreshing Firebase call and no file in
/// this package changes.
///
/// The returned value is used in exactly one place — the `Authorization`
/// header — and is never logged, never stored, and never placed in a URL
/// (spec `client/0003` N-14, ADR-B D-10).
typedef AuthTokenProvider = Future<String?> Function();

/// An [AuthTokenProvider] that always reports an anonymous caller.
///
/// Used by the health probe and by tests that assert the unauthenticated path.
Future<String?> anonymousToken() async => null;

/// The sentence a failed credential read is reported with.
///
/// Shared by both transports so the two cannot describe one event in two
/// ways. It says nothing about *why* — the identity SDK's own text is the
/// library's, not ours to show (N-14) — and it is a `TransportFailure` in
/// both, because a request that never left is what a caller has to handle.
const String credentialUnavailable = 'the session could not be read';
