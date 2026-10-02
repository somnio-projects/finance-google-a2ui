/// The cache key of one read of the views endpoint.
///
/// Both halves sorted, so the same request written two ways is one entry:
/// `?view=a&view=b` and `?view=b&view=a` name the same response. A function
/// of its own so `ViewsRepository` stays inside the 150-line budget without
/// shedding a comment.
String viewCacheKey(
  String path,
  List<String> views,
  Map<String, String> options,
) {
  final sortedViews = <String>[...views]..sort();
  final pairs =
      options.entries.map((option) => '${option.key}=${option.value}').toList()
        ..sort();
  return '$path?${sortedViews.join(",")}&${pairs.join("&")}';
}
