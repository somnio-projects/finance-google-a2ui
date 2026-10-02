import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The Home shell's two measured palettes (spec 0026 §2), and the lookup the
/// theme uses. Split from `home_tokens.dart` under the 150-line budget along
/// the seam it already had: the class says what a token *is*, this says what
/// each one *measured* on the two artboards.

/// The tokens for [brightness].
HomeTokens homeTokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? homeTokensDark : homeTokensLight;

/// Measured from the light artboard.
const HomeTokens homeTokensLight = HomeTokens(
  page: Color(0xFFF7F6FB),
  header: Color(0xFFFDFBFF),
  card: Color(0xFFFDFBFF),
  cardBorder: Color(0xFFEAE7F0),
  text: Color(0xFF1A1B20),
  muted: Color(0xFF5F6169),
  gain: Color(0xFF12805C),
  loss: Color(0xFFC0362C),
  badge: Color(0xFFEAE7F5),
  badgeDot: Color(0xFF7A5CFF),
  badgeText: Color(0xFF4A3F8A),
  segmentBorder: Color(0xFFC4C6D0),
  segmentSelected: Color(0xFF4F5DFF),
  segmentSelectedText: Color(0xFFFFFFFF),
  segmentText: Color(0xFF44464E),
  chip: Color(0xFFFDFBFF),
  chipBorder: Color(0xFFC4C6D0),
  chipText: Color(0xFF3A2F70),
  ticker: Color(0xFFEAE7F5),
  tickerText: Color(0xFF4A3F8A),
  nav: Color(0xFFF0EDF7),
  navBorder: Color(0xFFE3E0EA),
  navPill: Color(0xFFDCD8F2),
  navSelectedText: Color(0xFF3A2F70),
  navText: Color(0xFF5F6169),
  catalogBorder: Color(0xFFD9D6E0),
  catalogText: Color(0xFF8A8D96),
  rowDivider: Color(0xFFF0EEF5),
  accent: Color(0xFF4F5DFF),
);

/// Measured from the dark artboard.
const HomeTokens homeTokensDark = HomeTokens(
  page: Color(0xFF0B0C10),
  header: Color(0xFF0E0F13),
  card: Color(0xFF15161C),
  cardBorder: Color(0xFF24252D),
  text: Color(0xFFE5E1E9),
  muted: Color(0xFFA4A6B0),
  gain: Color(0xFF4ADE9E),
  loss: Color(0xFFFF6B5E),
  badge: Color(0xFF232036),
  badgeDot: Color(0xFFB9C0FF),
  badgeText: Color(0xFFC9CBFF),
  segmentBorder: Color(0xFF45464F),
  segmentSelected: Color(0xFFB9C0FF),
  segmentSelectedText: Color(0xFF151A54),
  segmentText: Color(0xFFA4A6B0),
  chip: Color(0xFF15161C),
  chipBorder: Color(0xFF45464F),
  chipText: Color(0xFFC9CBFF),
  ticker: Color(0xFF232036),
  tickerText: Color(0xFFC9CBFF),
  nav: Color(0xFF131319),
  navBorder: Color(0xFF24252D),
  navPill: Color(0xFF2D2A44),
  navSelectedText: Color(0xFFC9CBFF),
  navText: Color(0xFFA4A6B0),
  catalogBorder: Color(0xFF3A3B44),
  catalogText: Color(0xFFA4A6B0),
  rowDivider: Color(0xFF24252D),
  accent: Color(0xFF7A83FF),
);
