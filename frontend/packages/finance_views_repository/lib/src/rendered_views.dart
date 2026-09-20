import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';
import 'package:finance_views_repository/src/view_payload.dart';

/// The envelope `GET /v1/portfolios/{id}/views` answers with.
///
/// [asOf] stays a **string**, exactly as the backend sent it. Parsing it into
/// a `DateTime` would only be useful in order to format it, and formatting is
/// the client's job in no case (N-1); the portfolio's time is the backend's
/// and is never a device clock read (N-13).
class RenderedViews extends Equatable {
  /// Creates an envelope.
  const RenderedViews({
    required this.asOf,
    required this.portfolioId,
    required this.views,
    required this.etag,
  });

  /// Decodes the envelope, throwing [PayloadContractException] when the shape
  /// is not the one the contract declares.
  factory RenderedViews.fromJson(Object? json, {String? etag}) {
    if (json is! Map<String, dynamic>) {
      throw const PayloadContractException(
        ContractFailure('<root>', 'a JSON object'),
      );
    }
    final asOf = json['as_of'];
    final portfolioId = json['portfolio_id'];
    final views = json['views'];
    if (asOf is! String) {
      throw const PayloadContractException(
        ContractFailure('as_of', 'a string'),
      );
    }
    if (portfolioId is! String) {
      throw const PayloadContractException(
        ContractFailure('portfolio_id', 'a string'),
      );
    }
    if (views is! Map<String, dynamic>) {
      throw const PayloadContractException(
        ContractFailure('views', 'an object keyed by view id'),
      );
    }
    return RenderedViews(
      asOf: asOf,
      portfolioId: portfolioId,
      etag: etag,
      views: <String, ViewPayload>{
        for (final entry in views.entries)
          entry.key: ViewPayload.fromJson(entry.value),
      },
    );
  }

  /// The instant the portfolio was valued, verbatim from the backend.
  final String asOf;

  /// The portfolio the views were rendered for, e.g. `current`.
  final String portfolioId;

  /// One entry per requested view id, keyed by that id.
  final Map<String, ViewPayload> views;

  /// The strong `ETag` this envelope was served with, for revalidation.
  final String? etag;

  /// Re-labels the envelope with [etag], used when a 304 confirms the cached
  /// copy is still current.
  RenderedViews withEtag(String? etag) => RenderedViews(
    asOf: asOf,
    portfolioId: portfolioId,
    views: views,
    etag: etag,
  );

  @override
  List<Object?> get props => <Object?>[asOf, portfolioId, views, etag];
}
