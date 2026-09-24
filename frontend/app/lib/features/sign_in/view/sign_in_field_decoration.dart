import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// The design's outlined e-mail field: 56px, radius 8, a hairline that turns
/// into a 2px accent when focused, the label floating in the border.
InputDecoration signInFieldDecoration(
  LoginTokens tokens, {
  required bool focused,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: 'Email',
    hintText: 'you@company.com',
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: TextStyle(fontSize: 12, color: tokens.fieldLabel),
    floatingLabelStyle: TextStyle(
      fontSize: 12,
      color: focused ? tokens.fieldFocus : tokens.fieldLabel,
    ),
    hintStyle: TextStyle(fontSize: 15, color: tokens.placeholder),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    enabledBorder: border(tokens.fieldBorder),
    focusedBorder: border(tokens.fieldFocus, width: 2),
    disabledBorder: border(tokens.fieldBorder),
  );
}
