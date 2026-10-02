import 'package:equatable/equatable.dart';
import 'package:finance_core/src/app_failure.dart';

/// The outcome of an operation that is allowed to fail.
///
/// Failure is a value here, not an exception: every boundary that can fail
/// returns a [Result], so a caller cannot forget to handle it the way a bare
/// `Future<T>` lets it forget a `catch`. The subtypes are `sealed`, so a
/// `switch` over a [Result] is exhaustive and the analyzer — not review —
/// catches the branch nobody wrote.
sealed class Result<T> extends Equatable {
  const Result();

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// The value when this is an [Ok], otherwise `null`.
  ///
  /// Prefer a `switch` over this accessor: it cannot distinguish a failure
  /// from a successful `null`.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure when this is an [Err], otherwise `null`.
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Collapses both branches into a single value of type [R].
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppFailure failure) onErr,
  }) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onErr(failure),
  };
}

/// A successful [Result] carrying [value].
final class Ok<T> extends Result<T> {
  /// Wraps [value] as a success.
  const Ok(this.value);

  /// The value the operation produced.
  final T value;

  @override
  List<Object?> get props => <Object?>[value];
}

/// A failed [Result] carrying [failure].
final class Err<T> extends Result<T> {
  /// Wraps [failure] as a failure.
  const Err(this.failure);

  /// Why the operation did not produce a value.
  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
