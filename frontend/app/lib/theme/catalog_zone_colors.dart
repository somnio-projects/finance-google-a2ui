import 'package:flutter/material.dart';

/// The colours of a detail page's three zones, **measured** from the six
/// `Catalog_<Component>.dc.html` pages (spec frontend/0013 §2): the dark
/// schema panel and its syntax colours, the prompt panel, and the Do /
/// Don't cards. A plain value inside `CatalogTokens` rather than a second
/// `ThemeExtension`, so the theme registers the catalog once.
@immutable
class CatalogZoneColors {
  /// Creates the set.
  const CatalogZoneColors({
    required this.code,
    required this.codeBorder,
    required this.codeText,
    required this.codeKey,
    required this.codeString,
    required this.codeType,
    required this.codeComment,
    required this.prompt,
    required this.promptBorder,
    required this.promptAccent,
    required this.promptLabel,
    required this.promptText,
    required this.doCard,
    required this.doBorder,
    required this.doBadge,
    required this.doBadgeText,
    required this.doText,
    required this.doStrong,
    required this.dontCard,
    required this.dontBorder,
    required this.dontBadge,
    required this.dontBadgeText,
    required this.dontText,
    required this.dontStrong,
  });

  /// Zone 2 panel.
  final Color code;

  /// Zone 2 hairline; the light panel has none and names its own fill.
  final Color codeBorder;

  /// Zone 2 base text.
  final Color codeText;

  /// Zone 2: a key.
  final Color codeKey;

  /// Zone 2: a string value.
  final Color codeString;

  /// Zone 2: a type.
  final Color codeType;

  /// Zone 2: a comment.
  final Color codeComment;

  /// Zone 3 panel.
  final Color prompt;

  /// Zone 3 hairline.
  final Color promptBorder;

  /// Zone 3 left rule.
  final Color promptAccent;

  /// Zone 3 `Injected into system prompt` label.
  final Color promptLabel;

  /// Zone 3 fragment text.
  final Color promptText;

  /// Do card fill.
  final Color doCard;

  /// Do card hairline.
  final Color doBorder;

  /// Do badge circle.
  final Color doBadge;

  /// Do badge glyph.
  final Color doBadgeText;

  /// Do sentence.
  final Color doText;

  /// Do `Do` word.
  final Color doStrong;

  /// Don't card fill.
  final Color dontCard;

  /// Don't card hairline.
  final Color dontBorder;

  /// Don't badge circle.
  final Color dontBadge;

  /// Don't badge glyph.
  final Color dontBadgeText;

  /// Don't sentence.
  final Color dontText;

  /// Don't `Don't` word.
  final Color dontStrong;
}
