import 'package:finance_app/components/holdings_allocation/allocation_group.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The grouping toggle the design draws above the donut (GGU-145).
///
/// One segment per entry of the payload's `groups[]`, showing the backend's
/// own word and sending the backend's own value back. The client decides
/// neither: which segment is lit is `selected`, and what it says is `label`.
///
/// **It reuses the app's segment colours rather than inventing a palette.**
/// `HomeTokens` already carries the four measured values for exactly this
/// control — the Home range selector and the Holdings tab draw the same 38 pt
/// bordered pill — and a second set of near-identical colours is the drift
/// `frontend/0029` OD-4 exists to prevent. The **shape** is not measured yet:
/// the design export we hold predates this toggle, so the geometry below is
/// the app's existing one and `specs/frontend/0033` OD-1 records that it is
/// borrowed rather than read.
class HoldingsAllocationToggle extends StatelessWidget {
  /// Creates the toggle.
  const HoldingsAllocationToggle({
    required this.groups,
    required this.onSelected,
    this.isBusy = false,
    super.key,
  });

  /// The control's height, as the app's other segmented pills.
  static const double height = 34;

  /// Its corner radius.
  static const double radius = 18;

  /// Horizontal padding inside a segment.
  static const double segmentPadding = 12;

  /// The segments, in the order the payload sent them (N-10).
  final List<AllocationGroup> groups;

  /// Called with a segment's `value`, to be sent back as `group_by`.
  final ValueChanged<String> onSelected;

  /// True while a re-render is in flight; the control greys and stops
  /// answering, because the figures beside it are the previous grouping's.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Opacity(
      opacity: isBusy ? 0.5 : 1,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: tokens.segmentBorder),
          borderRadius: BorderRadius.circular(radius),
        ),
        // Scrolls rather than squeezing, for the reason GGU-144 records one
        // component over: three segments do not fit a phone column, and a
        // label clipped mid-word is worse than a drag.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final group in groups)
                _Segment(
                  group: group,
                  tokens: tokens,
                  first: group == groups.first,
                  onTap: isBusy ? null : () => onSelected(group.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.group,
    required this.tokens,
    required this.first,
    required this.onTap,
  });

  final AllocationGroup group;
  final HomeTokens tokens;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: group.selected,
    label: group.label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: group.selected ? tokens.segmentSelected : null,
          border: first
              ? null
              : Border(left: BorderSide(color: tokens.segmentBorder)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HoldingsAllocationToggle.segmentPadding,
          ),
          child: Center(
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: group.selected ? FontWeight.w600 : FontWeight.w400,
                color: group.selected
                    ? tokens.segmentSelectedText
                    : tokens.segmentText,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
