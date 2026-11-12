import 'dart:async';

import 'package:finance_app/router/app_routes.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter/foundation.dart';

/// The router's one auth decision (ADR-I D-3: a single gate, no per-screen
/// checks), as a [Listenable] `go_router` re-evaluates on every change.
///
/// Three answers, and the location the person asked for survives all of
/// them (GGU-154):
///
/// - **still finding out** — not yet known, a session being restored, or a
///   registry that could not answer — is the start-up surface. It used to be
///   the sign-in screen, which a signed-in person then watched for seconds
///   (GGU-163) or was left on for good when the check failed (GGU-159);
/// - **signed in** opens the shell, at the remembered location when it comes
///   through a gateway;
/// - **anything else** — signed out, not provisioned, a sign-in in flight —
///   is the sign-in screen, which draws no tab bar.
///
/// The gateways carry the wanted location as `?from=`, so a cold load of
/// `/#/holdings` waits on `/starting?from=%2Fholdings` and lands on Holdings,
/// and an e-mail link requested from `/sign-in?from=…` comes back to it.
class AuthGate extends ChangeNotifier {
  /// Creates the gate over [repository] and starts listening to it.
  AuthGate(AuthRepository repository) : _repository = repository {
    _subscription = repository.changes.listen((_) => notifyListeners());
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthState> _subscription;

  /// Where the person stands now.
  AuthState get state => _repository.state;

  /// Where [uri] must go instead, or null to let it through.
  String? redirectFor(Uri uri) {
    final atStartup = uri.path == AppRoutes.startup;
    final atSignIn = AppRoutes.isSignIn(uri.path);
    final atGateway = atStartup || atSignIn;
    final wanted = atGateway ? rememberedRoute(uri) : uri.toString();
    final state = this.state;
    if (state.isStarting) {
      return atStartup ? null : gatewayRoute(AppRoutes.startup, wanted);
    }
    if (state.allowsShell) return atGateway ? wanted : null;
    return atSignIn ? null : gatewayRoute(AppRoutes.signIn, wanted);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
