part of 'portfolio_views_bloc.dart';

/// Something that asks [PortfolioViewsBloc] to do work.
sealed class PortfolioViewsEvent extends Equatable {
  const PortfolioViewsEvent();
}

/// Asks for [views] to be rendered for [portfolioId].
///
/// [views] are ids taken from the backend's catalog; the client never builds
/// one (N-6). [options] are query options the requested views declare (N-7).
final class PortfolioViewsRequested extends PortfolioViewsEvent {
  /// Requests [views], defaulting to the caller's own portfolio.
  const PortfolioViewsRequested({
    required this.views,
    this.portfolioId = 'current',
    this.options = const <String, String>{},
  });

  /// The view ids to render, at most `ViewsRepository.maxViewsPerRequest`.
  final List<String> views;

  /// The portfolio to render them for. `current` is the well-known id that
  /// resolves to the authenticated caller's own portfolio.
  final String portfolioId;

  /// Options applied to **every** requested view — the read endpoint takes one
  /// flat set, so an option only one of them declares fails the whole request.
  final Map<String, String> options;

  @override
  List<Object?> get props => <Object?>[views, portfolioId, options];
}
