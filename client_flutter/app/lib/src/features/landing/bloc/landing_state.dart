import 'package:flutter/foundation.dart';

enum LandingStatus { initial, loading, success, failure }

/// State for the landing bloc.
final class LandingState {
  const LandingState({
    this.status = .initial,
    this.surfaceIds = const [],
    this.loadingTextIndex = 0,
    this.error,
  });

  final LandingStatus status;

  /// Ids of the surfaces currently rendered by the agent.
  final List<String> surfaceIds;

  /// Grows while loading; the view wraps it around its list of texts.
  final int loadingTextIndex;

  final String? error;

  bool get isLoading => status == .loading;

  LandingState copyWith({
    LandingStatus? status,
    List<String>? surfaceIds,
    int? loadingTextIndex,
    String? error,
  }) {
    return LandingState(
      status: status ?? this.status,
      surfaceIds: surfaceIds ?? this.surfaceIds,
      loadingTextIndex: loadingTextIndex ?? this.loadingTextIndex,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LandingState &&
      other.status == status &&
      listEquals(other.surfaceIds, surfaceIds) &&
      other.loadingTextIndex == loadingTextIndex &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(surfaceIds),
    loadingTextIndex,
    error,
  );
}
