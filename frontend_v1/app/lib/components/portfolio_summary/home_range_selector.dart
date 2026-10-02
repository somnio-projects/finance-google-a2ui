import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// One segment of the range selector: the code the backend declares and the
/// short word the design prints on it.
class RangeSegment {
  /// Creates the segment.
  const RangeSegment(this.code, this.label);

  /// The declared option value (`1d`, `1w`, `1m`, `ytd`, `1y`, `all`).
  final String code;

  /// The design's caption.
  final String label;
}

/// The six ranges, in the design's order.
const List<RangeSegment> rangeSegments = <RangeSegment>[
  RangeSegment('1d', '1D'),
  RangeSegment('1w', '1W'),
  RangeSegment('1m', '1M'),
  RangeSegment('ytd', 'YTD'),
  RangeSegment('1y', '1Y'),
  RangeSegment('all', 'All'),
];

/// The `1D · 1W · 1M · YTD · 1Y · All` control (spec 0026 §2).
///
/// A 38px strip with a 1px border at radius 20; the selected segment fills
/// indigo with white text, the rest print on the strip. The captions are
/// navigation chrome like the tab labels, not portfolio data; the word the
/// hero prints after the change (`today`, `this week`…) is the server's.
class HomeRangeSelector extends StatelessWidget {
  /// Creates the selector.
  const HomeRangeSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The selected code.
  final String selected;

  /// Called with the code of the segment tapped.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: tokens.segmentBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          for (final segment in rangeSegments)
            Expanded(
              child: _Segment(
                segment: segment,
                selected: segment.code == selected,
                onTap: () => onSelected(segment.code),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final RangeSegment segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: segment.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          color: selected ? tokens.segmentSelected : null,
          child: Text(
            segment.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: selected ? tokens.segmentSelectedText : tokens.segmentText,
            ),
          ),
        ),
      ),
    );
  }
}
