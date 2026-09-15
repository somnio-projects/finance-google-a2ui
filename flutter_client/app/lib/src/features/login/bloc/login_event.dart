/// Events for the login bloc.
sealed class LoginEvent {
  const LoginEvent();
}

/// The user submitted the login form.
final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.username, required this.password});

  final String username;
  final String password;
}
