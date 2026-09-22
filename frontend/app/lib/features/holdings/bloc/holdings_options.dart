/// The declared options the Holdings tab sends, in one place.
///
/// Split out of `HoldingsBloc` under the 150-line budget, along a seam worth
/// having anyway: every key here is an option one of the two views
/// **declares**, and keeping them together is what makes it obvious that
/// `asset_class` and `query` never travel with the allocation card. The read
/// endpoint applies ONE flat option set to every view in a request, and the
/// card declares neither, so sending them together would answer 422 for the
/// whole request rather than ignoring them (N-7). That is why the tab issues
/// two single-id reads instead of one.
library;

/// The `asset_class` value that means *no filter* — the chip the payload
/// ships first, and the projection's own default.
const String everyAssetClass = 'all';

/// `holdings.allocation.v1` grouped by [groupBy]: whole dollars, no headline.
Map<String, String> allocationOptionsFor(String groupBy) => <String, String>{
  'group_by': groupBy,
  'precision': '0',
  'headline': 'false',
};

/// `holdings.positions.v1` scoped by the sheet and the search box.
///
/// An unset filter is an **absent** key, not `all` or `''`: the projection
/// defaults both, and sending a default back would put two spellings of "no
/// filter" into the ETag's option hash.
Map<String, String> positionsOptionsFor(String assetClass, String query) =>
    <String, String>{
      if (assetClass != everyAssetClass) 'asset_class': assetClass,
      if (query.isNotEmpty) 'query': query,
    };
