/// Whether [value] is shaped like an e-mail address: something, one `@`, a
/// dotted domain, no spaces. Deliberately shallow — the provider and the
/// registry own the real verdict; this only keeps `not-an-email` from ever
/// becoming a request (GGU-155).
bool looksLikeEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$').hasMatch(value);

/// The sentence under the field when [looksLikeEmail] says no.
const String invalidEmailMessage = 'Enter a valid email address.';
