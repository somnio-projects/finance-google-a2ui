import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The avatar's sheet: who is signed in, and the one way out (G-3).
///
/// Not an artboard of its own — the design's header has the avatar and no
/// menu — so it borrows the Home card's chrome and says the minimum.
Future<void> showSessionSheet(
  BuildContext context, {
  required VoidCallback onSignOut,
}) {
  final tokens = HomeTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Signed in to the preview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Signing out clears everything this browser cached.',
            style: TextStyle(fontSize: 12.5, color: tokens.muted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                onSignOut();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.loss,
                side: BorderSide(color: tokens.segmentBorder),
                shape: const StadiumBorder(),
              ),
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    ),
  );
}
