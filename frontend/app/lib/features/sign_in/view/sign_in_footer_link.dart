import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

/// A footer link: on the web a real `<a href target=_blank>`, elsewhere a
/// tap that launches [uri] (GGU-156).
///
/// Exposed once, as a link named exactly [label]. The visible text is the
/// only name: no tooltip, so the URL is not read out a second time.
class SignInFooterLink extends StatelessWidget {
  /// Creates the link.
  const SignInFooterLink({
    required this.uri,
    required this.label,
    required this.style,
    super.key,
  });

  /// Where it goes.
  final Uri uri;

  /// What it says, and its accessible name.
  final String label;

  /// How it looks.
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Link(
    uri: uri,
    target: LinkTarget.blank,
    builder: (context, followLink) => Semantics(
      link: true,
      label: label,
      excludeSemantics: true,
      onTap: followLink,
      child: InkWell(
        onTap: followLink,
        child: Text(label, style: style),
      ),
    ),
  );
}
