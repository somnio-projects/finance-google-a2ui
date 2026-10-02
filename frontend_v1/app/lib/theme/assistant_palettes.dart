import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:flutter/material.dart';

/// `FlowA-Assistant.dc.html`, light.
const AssistantTokens assistantTokensLight = AssistantTokens(
  avatar: <Color>[Color(0xFF4F5DFF), Color(0xFF7A5CFF)],
  pill: Color(0xFFEAE7F5),
  pillText: Color(0xFF5F6169),
  badge: Color(0xFFEAE7F5),
  badgeDot: Color(0xFF7A5CFF),
  badgeText: Color(0xFF4A3F8A),
  bubble: Color(0xFF4F5DFF),
  bubbleText: Color(0xFFFFFFFF),
  label: Color(0xFF5F6169),
  dot: Color(0xFF7A5CFF),
  skeletonBar: Color(0x14787A8C),
  composing: Color(0xFF8A5CF0),
  chip: Color(0xFFFDFBFF),
  chipBorder: Color(0xFFC4C6D0),
  chipText: Color(0xFF3A2F70),
  fieldBorder: Color(0xFFC4C6D0),
  placeholder: Color(0xFF8A8D96),
  mic: Color(0xFFEAE7F5),
  micGlyph: Color(0xFF4A3F8A),
  send: Color(0xFF4F5DFF),
  sendGlyph: Color(0xFFFFFFFF),
  sendDisabled: Color(0xFFC9C4E8),
);

/// `FlowA-Assistant.dc.html`, dark.
const AssistantTokens assistantTokensDark = AssistantTokens(
  avatar: <Color>[Color(0xFF4F5DFF), Color(0xFF7A5CFF)],
  pill: Color(0xFF232036),
  pillText: Color(0xFFC9CBD4),
  badge: Color(0xFF232036),
  badgeDot: Color(0xFFB9C0FF),
  badgeText: Color(0xFFC9CBFF),
  bubble: Color(0xFF4F5DFF),
  bubbleText: Color(0xFFFFFFFF),
  label: Color(0xFFA4A6B0),
  dot: Color(0xFF7A5CFF),
  skeletonBar: Color(0x1F9A9CB0),
  composing: Color(0xFFB9C0FF),
  chip: Color(0xFF15161C),
  chipBorder: Color(0xFF45464F),
  chipText: Color(0xFFC9CBFF),
  fieldBorder: Color(0xFF45464F),
  placeholder: Color(0xFF7C7F89),
  mic: Color(0xFF232036),
  micGlyph: Color(0xFFC9CBFF),
  send: Color(0xFFB9C0FF),
  sendGlyph: Color(0xFF151A54),
  sendDisabled: Color(0xFF3A3556),
);

/// The palette for [brightness].
AssistantTokens assistantTokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? assistantTokensDark : assistantTokensLight;
