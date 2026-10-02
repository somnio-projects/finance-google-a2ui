import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The design's third state: a dark bar with a `!` ring, the sentence, and
/// `Dismiss`. [message] is the backend's or the provider's, verbatim.
void showSignInSnack(BuildContext context, String message) {
  final tokens = LoginTokens.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.snack,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 8),
        content: Row(
          children: <Widget>[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.snackIcon, width: 1.5),
              ),
              child: Text(
                '!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.snackIcon,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: tokens.snackText,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                context.read<SignInBloc>().add(const SignInMessageDismissed());
              },
              child: Text(
                'Dismiss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.snackAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
