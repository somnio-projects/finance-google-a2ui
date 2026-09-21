enum LoginStatus { initial, loading, success }

/// State for the login bloc.
final class LoginState {
  const LoginState({this.status = .initial});

  final LoginStatus status;

  bool get isLoading => status == .loading;

  LoginState copyWith({LoginStatus? status}) {
    return LoginState(status: status ?? this.status);
  }

  @override
  bool operator ==(Object other) =>
      other is LoginState && other.status == status;

  @override
  int get hashCode => status.hashCode;
}
