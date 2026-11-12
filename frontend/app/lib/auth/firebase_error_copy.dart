/// The sentence a person reads when the identity provider said no.
///
/// Takes the SDK's `code` and `message` as strings, not the exception, so the
/// Firebase seam stays three files (`firebase_seam_test.dart`). Known codes
/// get our own copy; an SDK sentence passes through only when it reads like
/// one; a bare code (`INVALID_EMAIL`, `auth/invalid-email`) is never shown
/// (GGU-155).
String firebaseErrorCopy(String code, String? message) {
  final known = _known[code.replaceFirst('auth/', '')];
  if (known != null) return known;
  final text = message?.trim() ?? '';
  final codeLike =
      RegExp(r'^[A-Z0-9_]+$').hasMatch(text) ||
      text.contains('auth/') ||
      text.contains('firebase_auth/');
  return text.isEmpty || codeLike ? firebaseFallbackCopy : text;
}

/// What is said when nothing better is known.
const String firebaseFallbackCopy =
    'We could not complete the sign-in. Try again.';

const Map<String, String> _known = <String, String>{
  'invalid-email': 'Enter a valid email address.',
  'too-many-requests': 'Too many attempts. Wait a few minutes and try again.',
  'quota-exceeded': 'We cannot send more sign-in links right now. Try later.',
  'network-request-failed':
      'We could not reach the server. Check your connection.',
};
