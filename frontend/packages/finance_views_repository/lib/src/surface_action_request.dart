import 'package:equatable/equatable.dart';

/// A tap a surface sends back, instead of a sentence about it (spec 0022 §3.1).
///
/// The client names a **registered** action id and scalar arguments drawn
/// from bounds the same payload published; the backend composes the prompt.
/// Nothing here is prose, a field path or a view — a chip key, a driver
/// symbol, and the id that says which registered behaviour they belong to.
/// It lives in the repository layer so blocs and components never touch the
/// transport (ADR-L).
final class SurfaceActionRequest extends Equatable {
  /// Creates the request for [action] with [args].
  const SurfaceActionRequest({
    required this.action,
    this.args = const <String, String>{},
  });

  /// The registered action id, e.g. `ask.suggested.v1`.
  final String action;

  /// The scalar arguments, e.g. `{'suggestion': 'tax-lots'}`.
  final Map<String, String> args;

  @override
  List<Object?> get props => <Object?>[action, args];
}
