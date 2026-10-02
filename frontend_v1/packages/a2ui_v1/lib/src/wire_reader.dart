/// Why one wire message could not be read.
///
/// Thrown only inside this package, by the readers below, and caught at the
/// message boundary (`decodeAgentMessage`), which turns it into a
/// `VALIDATION_FAILED` error for that one message. It never crosses the
/// package's API: the extension spec processes a `DataPart`'s list one message
/// at a time and a bad message must not take its neighbours down.
final class A2uiFormatException implements Exception {
  /// Creates the exception for the field at [path].
  const A2uiFormatException(this.path, this.message);

  /// A JSON Pointer to the offending field, e.g. `/createSurface/surfaceId`.
  final String path;

  /// One sentence, safe to send back to the agent.
  final String message;

  @override
  String toString() => 'A2uiFormatException($path): $message';
}

/// Reads [json] as an object, or throws for the field at [path].
Map<String, Object?> readObject(Object? json, String path) {
  if (json is Map<String, Object?>) return json;
  throw A2uiFormatException(path, 'expected a JSON object');
}

/// Reads the string at `object[key]`, or throws.
String readString(Map<String, Object?> object, String key, String path) {
  final value = object[key];
  if (value is String) return value;
  throw A2uiFormatException('$path/$key', 'expected a string');
}

/// Reads the string at `object[key]`, or `null` when it is absent.
String? readOptionalString(
  Map<String, Object?> object,
  String key,
  String path,
) {
  if (!object.containsKey(key)) return null;
  return readString(object, key, path);
}

/// Reads the list at `object[key]`, or throws.
List<Object?> readList(Map<String, Object?> object, String key, String path) {
  final value = object[key];
  if (value is List<Object?>) return value;
  throw A2uiFormatException('$path/$key', 'expected an array');
}
