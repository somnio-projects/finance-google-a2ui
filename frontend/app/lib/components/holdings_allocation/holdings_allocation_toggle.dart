import 'package:finance_app/components/holdings_allocation/allocation_group.dart';
import 'package:finance_app/components/holdings_allocation/allocation_toggle_tokens.dart';
import 'package:flutter/material.dart';

/// The grouping toggle the design draws above the donut (GGU-145).
///
/// One segment per entry of the payload's `groups[]`, showing the backend's
/// own word and sending the backend's own value back. The client decides
/// neither: which segment is lit is `selected`, and what it says is `label`.
///
/// Every colour and every measurement comes from [AllocationToggleTokens],
/// read off the Figma `SegmentedControl` — a filled pill with the selected
/// segment floating inside it, which is a different control from the bordered
/// one the Home range selector draws. It borrowed `HomeTokens` until the
/// design was measured; `specs/frontend/0033` records the swap.
class HoldingsAllocationToggle extends StatelessWidget {
  /// Creates the toggle.
  const HoldingsAllocationToggle({
    required this.groups,
    required this.onSelected,
    this.isBusy = false,
    super.key,
  });

  /// The segments, in the order the payload sent them (N-10).
  final List<AllocationGroup> groups;

  /// Called with a segment's `value`, to be sent back as `group_by`.
  final ValueChanged<String> onSelected;

  /// True while a re-render is in flight; the control greys and stops
  /// answering, because the figures beside it are the previous grouping's.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = AllocationToggleTokens.of(context);
    return Opacity(
      opacity: isBusy ? 0.5 : 1,
      child: Container(
        height: AllocationToggleTokens.trackHeight,
        padding: const EdgeInsets.all(AllocationToggleTokens.trackPadding),
        decoration: BoxDecoration(
          color: tokens.track,
          borderRadius: BorderRadius.circular(AllocationToggleTokens.radius),
        ),
        // Scrolls rather than squeezing, for the reason GGU-144 records one
        // component over: three segments do not fit a phone column, and a
        // label clipped mid-word is worse than a drag.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final group in groups) ...<Widget>[
                if (group != groups.first)
                  const SizedBox(width: AllocationToggleTokens.segmentGap),
                _Segment(
                  group: group,
                  tokens: tokens,
                  onTap: isBusy ? null : () => onSelected(group.value),
                ),
              ],
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
    required this.onTap,
  });

  final AllocationGroup group;
  final AllocationToggleTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = tokens.selectedBorder;
    return Semantics(
      button: true,
      selected: group.selected,
      label: group.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: group.selected ? tokens.selectedSurface : null,
            border: group.selected && border != null
                ? Border.all(color: border)
                : null,
            borderRadius: BorderRadius.circular(AllocationToggleTokens.radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AllocationToggleTokens.segmentPaddingX,
              vertical: AllocationToggleTokens.segmentPaddingY,
            ),
            child: Center(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AllocationToggleTokens.labelSize,
                  fontWeight: AllocationToggleTokens.labelWeight,
                  height: AllocationToggleTokens.labelHeight,
                  color: group.selected ? tokens.selectedText : tokens.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
