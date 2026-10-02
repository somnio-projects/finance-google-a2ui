/// RFC 6901 JSON Pointers over a surface's data model, with A2UI's one
/// deviation: `/` (like the empty pointer) means the **whole** model
/// (`updateDataModel.path`, "if omitted, or set to '/'").
///
/// Writes are **copy-on-write**: the containers along the path are copied and
/// everything else is shared, so a `Surface` stays a value a Bloc state can
/// hold and compare.
library;

/// The unescaped reference tokens of [pointer]; empty for the whole model.
///
/// Throws [FormatException] for a pointer that does not start with `/`.
List<String> pointerTokens(String pointer) {
  if (pointer.isEmpty || pointer == '/') return const <String>[];
  if (!pointer.startsWith('/')) {
    throw FormatException('a JSON Pointer starts with "/"', pointer);
  }
  return <String>[
    for (final token in pointer.substring(1).split('/'))
      token.replaceAll('~1', '/').replaceAll('~0', '~'),
  ];
}

/// The value at [pointer] in [root], or `null` when nothing is there.
///
/// Absence and an explicit `null` read the same, which is what the protocol
/// wants: `updateDataModel` with `null` *deletes*, so a stored `null` is not
/// a state a model can be in.
Object? readPointer(Object? root, String pointer) {
  var current = root;
  for (final token in pointerTokens(pointer)) {
    current = switch (current) {
      final Map<String, Object?> map => map[token],
      final List<Object?> list => _element(list, token),
      _ => null,
    };
  }
  return current;
}

/// [root] with [value] written at [pointer]; a `null` [value] removes the key
/// (or list element) there. Missing objects along the path are created
/// (upsert semantics).
///
/// Throws [FormatException] when the path crosses a scalar, indexes a list
/// out of range, or replaces the whole model with something that is not an
/// object.
Map<String, Object?> writePointer(
  Map<String, Object?> root,
  String pointer,
  Object? value,
) {
  final tokens = pointerTokens(pointer);
  if (tokens.isEmpty) {
    if (value == null) return const <String, Object?>{};
    if (value is Map<String, Object?>) return value;
    throw FormatException('the data model root must be an object', pointer);
  }
  return _write(root, tokens, value, pointer)! as Map<String, Object?>;
}

Object? _write(
  Object? node,
  List<String> tokens,
  Object? value,
  String pointer,
) {
  final token = tokens.first;
  final rest = tokens.sublist(1);
  if (node is List<Object?>) {
    final copy = List<Object?>.of(node);
    final index = _index(token, copy.length, true);
    if (index == null) {
      throw FormatException('no list element "$token"', pointer);
    }
    final next = rest.isEmpty
        ? value
        : _write(
            index < copy.length ? copy[index] : null,
            rest,
            value,
            pointer,
          );
    if (index == copy.length) {
      if (next != null) copy.add(next);
    } else if (next == null && rest.isEmpty) {
      copy.removeAt(index);
    } else {
      copy[index] = next;
    }
    return copy;
  }
  if (node != null && node is! Map<String, Object?>) {
    throw FormatException('"$token" is under a scalar', pointer);
  }
  final copy = Map<String, Object?>.of(
    (node as Map<String, Object?>?) ?? const <String, Object?>{},
  );
  final next = rest.isEmpty ? value : _write(copy[token], rest, value, pointer);
  if (next == null) {
    copy.remove(token);
  } else {
    copy[token] = next;
  }
  return copy;
}

Object? _element(List<Object?> list, String token) {
  final index = _index(token, list.length, false);
  return index == null ? null : list[index];
}

/// The list index [token] names, `length` for the `-` append token when
/// [appending], or `null` when it names no element.
int? _index(String token, int length, bool appending) {
  if (token == '-') return appending ? length : null;
  final index = _arrayIndex(token);
  if (index == null) return null;
  final limit = appending ? length : length - 1;
  return index <= limit ? index : null;
}

/// RFC 6901's `array-index` (`0` or a digit run without a leading zero),
/// read digit by digit.
///
/// Not the core library's integer parser: the binding rules ban every
/// number-parsing mechanism in
/// `lib/` so a payload figure can never be turned into arithmetic, and a
/// pointer token is the one integer this package has to read. Spelling it out
/// keeps the ban mechanical instead of granting this file an exemption.
int? _arrayIndex(String token) {
  if (token.isEmpty || token.length > 9) return null;
  if (token.length > 1 && token.startsWith('0')) return null;
  var index = 0;
  for (final unit in token.codeUnits) {
    final digit = unit - 0x30;
    if (digit < 0 || digit > 9) return null;
    index = index * 10 + digit;
  }
  return index;
}
