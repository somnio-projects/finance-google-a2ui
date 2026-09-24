import 'dart:async';

import 'package:finance_app/router/app_routes.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter/foundation.dart';

/// The router's one auth decision (ADR-I D-3: a single gate, no per-screen
/// checks), as a [Listenable] `go_router` re-evaluates on every change.
///
/// Signed out, not provisioned or not yet known all land on the sign-in
/// screen — which draws no tab bar; signed in at the sign-in screen goes home.
class AuthGate extends ChangeNotifier {
  /// Creates the gate over [repository] and starts listening to it.
  AuthGate(AuthRepository repository) : _repository = repository {
    _subscription = repository.changes.listen((_) => notifyListeners());
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthState> _subscription;

  /// Where the person stands now.
  AuthState get state => _repository.state;

  /// Where [location] must go instead, or null to let it through.
  String? redirectFor(String location) {
    final atSignIn = AppRoutes.isSignIn(location);
    if (state.allowsShell) return atSignIn ? AppRoutes.home : null;
    return atSignIn ? null : AppRoutes.signIn;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
