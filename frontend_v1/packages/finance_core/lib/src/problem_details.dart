import 'package:equatable/equatable.dart';

/// An RFC 9457 `application/problem+json` document as this backend writes it.
///
/// The field names are the wire names, deliberately: this is a transcription
/// of a contract, so a reader can diff it against `backend/src/app/schemas/
/// problem.py` without translating.
///
/// **Branch on [type], never on [detail].** [type] is a stable URI the backend
/// promises; [detail] is prose that may be reworded at any time.
class ProblemDetails extends Equatable {
  /// Creates a problem document.
  const ProblemDetails({
    required this.type,
    required this.title,
    required this.status,
    required this.detail,
    this.instance,
    this.requestId,
  });

  /// Parses [json] when it is a problem document, otherwise returns `null`.
  ///
  /// A `null` return is the honest answer for a gateway's HTML error page or a
  /// proxy's plain-text body: the caller then reports a transport failure
  /// rather than inventing a problem document the backend never sent.
  static ProblemDetails? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final type = json['type'];
    final title = json['title'];
    final status = json['status'];
    final detail = json['detail'];
    if (type is! String || title is! String) return null;
    if (status is! int || detail is! String) return null;
    final instance = json['instance'];
    final requestId = json['request_id'];
    return ProblemDetails(
      type: type,
      title: title,
      status: status,
      detail: detail,
      instance: instance is String ? instance : null,
      requestId: requestId is String ? requestId : null,
    );
  }

  /// Stable URI identifying the problem kind, e.g.
  /// `https://errors.finance-a2ui/auth/expired-token`.
  final String type;

  /// Short, human-readable summary — usually the HTTP status phrase.
  final String title;

  /// The HTTP status code the response carried.
  final int status;

  /// Safe explanation of this occurrence. Never parsed, only shown or logged.
  final String detail;

  /// The path that produced the problem, when the backend supplied it.
  final String? instance;

  /// Correlation id, matching the `X-Request-ID` response header.
  final String? requestId;

  /// The trailing segment of [type], e.g. `auth/expired-token`.
  ///
  /// This is what call sites compare against, so that the error-namespace host
  /// can move without every comparison in the app moving with it.
  String get code {
    const namespace = 'https://errors.finance-a2ui/';
    return type.startsWith(namespace) ? type.substring(namespace.length) : type;
  }

  @override
  List<Object?> get props => <Object?>[
    type,
    title,
    status,
    detail,
    instance,
    requestId,
  ];
}
