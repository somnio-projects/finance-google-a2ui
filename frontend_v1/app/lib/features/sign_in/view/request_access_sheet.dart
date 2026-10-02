import 'package:finance_app/features/sign_in/view/sign_in_field_decoration.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// The *Request access* sheet: one field, one button (spec 0027 AC-6).
///
/// Not an artboard of its own in the design — the link exists, the sheet is
/// the smallest thing that makes it do something — so it borrows the
/// screen's field and button verbatim.
Future<void> showRequestAccessSheet(
  BuildContext context,
  ValueChanged<String> onSubmit,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: LoginTokens.of(context).page,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) => RequestAccessSheet(
    onSubmit: (email) {
      Navigator.of(sheet).pop();
      onSubmit(email);
    },
  ),
);

/// The sheet's body.
class RequestAccessSheet extends StatefulWidget {
  /// Creates the sheet.
  const RequestAccessSheet({required this.onSubmit, super.key});

  /// The sheet's title.
  static const String title = 'Request access';

  /// The sheet's one sentence.
  static const String blurb =
      'Leave the work e-mail you would sign in with. An admin reviews every '
      'request during the preview.';

  /// The button.
  static const String send = 'Send request';

  /// Called with the trimmed e-mail.
  final ValueChanged<String> onSubmit;

  @override
  State<RequestAccessSheet> createState() => _RequestAccessSheetState();
}

class _RequestAccessSheetState extends State<RequestAccessSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    if (email.isNotEmpty) widget.onSubmit(email);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        28,
        24,
        28,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            RequestAccessSheet.title,
            style: TextStyle(fontSize: 20, color: tokens.title),
          ),
          const SizedBox(height: 8),
          Text(
            RequestAccessSheet.blurb,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: tokens.subtitle,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: 15, color: tokens.title),
              decoration: signInFieldDecoration(tokens, focused: true),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: tokens.primaryText,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text(RequestAccessSheet.send),
            ),
          ),
        ],
      ),
    );
  }
}
