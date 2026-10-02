import 'package:equatable/equatable.dart';

/// A signed-in identity: the bearer token and where it came from.
///
/// [provider] is `firebase` for an ID token the identity provider will
/// refresh, or `preview` for the local stack's minted token (spec
/// backend/0027 OD-3), which is used as-is until it expires.
class AuthSession extends Equatable {
  /// Creates the session.
  const AuthSession({required this.token, required this.provider, this.email});

  /// The credential sent as `Authorization: Bearer`.
  final String token;

  /// `firebase` or `preview`.
  final String provider;

  /// The e-mail the provider vouched for, when it said one.
  final String? email;

  @override
  List<Object?> get props => <Object?>[token, provider, email];
}
