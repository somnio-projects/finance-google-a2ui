import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// `Login.dc.html`, light artboard (L1–L3).
const LoginTokens loginTokensLight = LoginTokens(
  page: Color(0xFFFDFBFF),
  title: Color(0xFF1A1B20),
  subtitle: Color(0xFF44464E),
  googleBorder: Color(0xFFC4C6D0),
  googleFill: Color(0xFFFFFFFF),
  googleText: Color(0xFF1A1B20),
  divider: Color(0xFFE3E2E6),
  dividerText: Color(0xFF8A8D96),
  fieldBorder: Color(0xFFC4C6D0),
  fieldFocus: Color(0xFF4F5DFF),
  fieldLabel: Color(0xFF5F6169),
  placeholder: Color(0xFF8A8D96),
  helper: Color(0xFF5F6169),
  primary: Color(0xFF4F5DFF),
  primaryText: Color(0xFFFFFFFF),
  invite: Color(0xFF5F6169),
  inviteLink: Color(0xFF9AA0AA),
  footer: Color(0xFF8A8D96),
  footerLink: Color(0xFF4F5DFF),
  footerSeparator: Color(0xFFC4C6D0),
  snack: Color(0xFF322F35),
  snackText: Color(0xFFE6E1E6),
  snackIcon: Color(0xFFFFB4AB),
  snackAction: Color(0xFFB9C0FF),
);

/// `Login.dc.html`, dark artboard (D1–D3).
const LoginTokens loginTokensDark = LoginTokens(
  page: Color(0xFF0E0F13),
  title: Color(0xFFE5E1E9),
  subtitle: Color(0xFFB6B8C2),
  googleBorder: Color(0xFF45464F),
  googleFill: Color(0xFF1B1C22),
  googleText: Color(0xFFE5E1E9),
  divider: Color(0xFF2A2B31),
  dividerText: Color(0xFF8A8D96),
  fieldBorder: Color(0xFF45464F),
  fieldFocus: Color(0xFFB9C0FF),
  fieldLabel: Color(0xFFA4A6B0),
  placeholder: Color(0xFF7C7F89),
  helper: Color(0xFFA4A6B0),
  primary: Color(0xFFB9C0FF),
  primaryText: Color(0xFF151A54),
  invite: Color(0xFFA4A6B0),
  inviteLink: Color(0xFF6F7280),
  footer: Color(0xFF7C7F89),
  footerLink: Color(0xFFB9C0FF),
  footerSeparator: Color(0xFF45464F),
  snack: Color(0xFFE6E1E6),
  snackText: Color(0xFF1A1B20),
  snackIcon: Color(0xFFC0362C),
  snackAction: Color(0xFF4F5DFF),
);

/// The palette for [brightness].
LoginTokens loginTokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? loginTokensDark : loginTokensLight;
