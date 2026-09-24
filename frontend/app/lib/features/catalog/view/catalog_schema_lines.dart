import 'package:finance_app/theme/catalog_zone_colors.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The lines of the Zone 2 panel, as spans in the design's syntax colours.
///
/// Every token here is a string the backend wrote — the component name, the
/// view id, each field's path, type, presence, binding, state and input,
/// each action's id, argument, control and label. The punctuation between
/// them is the only thing this file adds; nothing is derived (N-3).
class CatalogSchemaLines {
  /// Builds the span list for [entry] in [colors].
  const CatalogSchemaLines(this.entry, this.colors);

  /// The entry to print.
  final CatalogEntry entry;

  /// The zone's colours.
  final CatalogZoneColors colors;

  /// The panel's text, top to bottom.
  List<InlineSpan> build() => <InlineSpan>[
    ..._pair('component', entry.component),
    ..._pair('view', entry.id),
    _key('endpoints'),
    _plain(': '),
    _string(entry.endpoints.join(' · ')),
    _plain('\n'),
    _key('fields'),
    _plain(': {\n'),
    for (final field in entry.fields) ..._field(field),
    _plain('}\n'),
    _key('actions'),
    _plain(entry.actions.isEmpty ? ': []' : ': [\n'),
    for (final action in entry.actions) ..._action(action),
    if (entry.actions.isNotEmpty) _plain(']'),
  ];

  List<InlineSpan> _pair(String key, String value) => <InlineSpan>[
    _key(key),
    _plain(': '),
    _string(value),
    _plain('\n'),
  ];

  List<InlineSpan> _field(CatalogField field) => <InlineSpan>[
    _plain('  '),
    _key(field.path),
    _plain(': '),
    _type(field.type),
    _comment(
      '  // ${field.presence} · ${field.binding}'
      '${field.state == null ? '' : ' · state: ${field.state}'}'
      '${field.input == null ? '' : ' · ${field.input}'}',
    ),
    _plain('\n'),
  ];

  List<InlineSpan> _action(CatalogAction action) => <InlineSpan>[
    _plain('  '),
    _string(action.action),
    _plain('('),
    _key(action.arg),
    _plain(': '),
    _type(action.control),
    _plain(')'),
    _comment('  // ${action.label}'),
    _plain('\n'),
  ];

  TextSpan _plain(String text) => TextSpan(text: text);

  TextSpan _key(String text) => TextSpan(
    text: text,
    style: TextStyle(color: colors.codeKey),
  );

  TextSpan _string(String text) => TextSpan(
    text: '"$text"',
    style: TextStyle(color: colors.codeString),
  );

  TextSpan _type(String text) => TextSpan(
    text: text,
    style: TextStyle(color: colors.codeType),
  );

  TextSpan _comment(String text) => TextSpan(
    text: text,
    style: TextStyle(color: colors.codeComment),
  );
}
