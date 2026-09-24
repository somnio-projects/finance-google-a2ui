/// Splits [ids] into consecutive groups of at most [size], preserving order.
///
/// The read endpoint takes at most `MAX_VIEWS` ids per request, so a build
/// that registers more components than that cannot ask for them in one call.
/// Chunking is the client's half of that bound: it is not a client-side
/// filter, a re-rank or a truncation — **every** id is requested, in the order
/// given, just across more than one round trip (N-10 is untouched).
///
/// Throws [ArgumentError] when [size] is not positive, because a zero or
/// negative chunk size would otherwise loop forever or silently drop ids —
/// the two failure modes a caller would never see in a passing test.
List<List<String>> chunkViewIds(List<String> ids, int size) {
  if (size <= 0) {
    throw ArgumentError.value(size, 'size', 'must be greater than zero');
  }
  final chunks = <List<String>>[];
  for (var start = 0; start < ids.length; start += size) {
    final end = start + size < ids.length ? start + size : ids.length;
    chunks.add(ids.sublist(start, end));
  }
  return chunks;
}
