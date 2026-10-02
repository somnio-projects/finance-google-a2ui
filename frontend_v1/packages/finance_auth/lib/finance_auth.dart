/// Who is signed in, and whether they were invited.
///
/// Two questions, two seams. An `IdentityProvider` (Firebase in the browser,
/// nothing on a bare stack) answers *who*; the backend's provisioning
/// registry, reached through `AccessGateway`, answers *whether*
/// (spec backend/0027). `AuthRepository` joins them into one `AuthState` the
/// router gates on. Pure Dart: no Flutter, no widget, no Firebase type.
library;

export 'src/access_decision.dart';
export 'src/access_gateway.dart';
export 'src/auth_repository.dart';
export 'src/auth_session.dart';
export 'src/auth_state.dart';
export 'src/email_sign_in_outcome.dart';
export 'src/identity_provider.dart';
export 'src/sign_in_policy.dart';
