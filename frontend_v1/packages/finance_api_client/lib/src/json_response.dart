import 'package:equatable/equatable.dart';

/// A decoded, successful JSON response.
///
/// [body] is `null` exactly when [statusCode] is 304: the backend answered
/// "unchanged" and sent no body. A 304 is a success, not an error and not an
/// empty result — the caller re-renders what it already holds (spec
/// `client/0003` §6, ADR-K D-20).
class JsonResponse extends Equatable {
  /// Creates a decoded response.
  const JsonResponse({
    required this.statusCode,
    required this.body,
    required this.etag,
  });

  /// The HTTP status: 200 with a body, or 304 without one.
  final int statusCode;

  /// The decoded JSON body, or `null` on a 304.
  final Object? body;

  /// The strong `ETag` the backend sent, verbatim and quoted, or `null`.
  ///
  /// It is echoed back as `If-None-Match` unchanged: the quotes are part of
  /// the tag, and stripping them turns a revalidation into a full fetch.
  final String? etag;

  /// Whether the backend reported the cached copy is still current.
  bool get isNotModified => statusCode == 304;

  @override
  List<Object?> get props => <Object?>[statusCode, body, etag];
}
