import 'package:finance_app/features/sign_in/view/request_access_sheet.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// `Access is invite-only during the A2UI preview.` and the link that
/// opens the request sheet.
///
/// **Shown only where it is true.** The deployment says which door it has
/// (`GET /v1/sign-in-policy`, spec backend/0043); this widget is built only
/// when the answer was `invite-only`, and the screen draws nothing in its
/// place otherwise. An open deployment telling visitors it is invite-only is
/// the untruth that spec exists to remove, and design has not written a
/// sentence for the open door (0043 OD-4) — so there is none to put here.
class SignInInviteLine extends StatelessWidget {
  /// Creates the line.
  const SignInInviteLine({
    required this.onRequestAccess,
    this.requested = false,
    super.key,
  });

  /// The design's sentence.
  static const String sentence =
      'Access is invite-only during the A2UI preview.';

  /// The design's link.
  static const String link = 'Request access';

  /// What the line says once a request went out.
  static const String sent = 'Request sent — an admin will invite you.';

  /// Called with the e-mail typed into the sheet.
  final ValueChanged<String> onRequestAccess;

  /// Whether a request was accepted.
  final bool requested;

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    if (requested) {
      return Text(
        sent,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: tokens.invite),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: <Widget>[
        Text(sentence, style: TextStyle(fontSize: 12.5, color: tokens.invite)),
        GestureDetector(
          onTap: () => showRequestAccessSheet(context, onRequestAccess),
          child: Text(
            link,
            style: TextStyle(
              fontSize: 12.5,
              color: tokens.inviteLink,
              decoration: TextDecoration.underline,
              decorationColor: tokens.inviteLink,
            ),
          ),
        ),
      ],
    );
  }
}

/// `Open source · Apache 2.0 · GitHub · Privacy`.
class SignInFooter extends StatelessWidget {
  /// Creates the footer.
  const SignInFooter({super.key});

  /// The repository the link opens.
  static final Uri github = Uri.parse(
    'https://github.com/somnio-projects/finance-google-a2ui',
  );

  /// Where the privacy notes live.
  static final Uri privacy = Uri.parse(
    'https://github.com/somnio-projects/finance-google-a2ui/tree/develop/docs/compliance',
  );

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    final words = TextStyle(fontSize: 11.5, color: tokens.footer);
    final links = TextStyle(fontSize: 11.5, color: tokens.footerLink);
    final dot = TextStyle(color: tokens.footerSeparator);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: <Widget>[
        Text('Open source · Apache 2.0', style: words),
        Text('·', style: dot),
        Link(uri: github, label: 'GitHub', style: links),
        Text('·', style: dot),
        Link(uri: privacy, label: 'Privacy', style: links),
      ],
    );
  }
}

/// A footer link: the [uri] is what it stands for, and a test can read it.
class Link extends StatelessWidget {
  /// Creates the link.
  const Link({
    required this.uri,
    required this.label,
    required this.style,
    super.key,
  });

  /// Where it goes.
  final Uri uri;

  /// What it says.
  final String label;

  /// How it looks.
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: label,
    child: Tooltip(
      message: uri.toString(),
      child: Text(label, style: style),
    ),
  );
}
