import 'package:equatable/equatable.dart';

/// One segment of the grouping toggle, as `groups[]` publishes it (GGU-145).
///
/// The words are **the backend's**. A client that wrote "By asset class"
/// beside the `group_by` enum would be authoring copy for a value the server
/// owns, and it would not follow the `locale` option (N-1, N-9); it would
/// also silently narrow the enum, since the design draws two segments and the
/// option declares three. So the payload names every declared choice and this
/// binds them.
class AllocationGroup extends Equatable {
  /// Creates a segment.
  const AllocationGroup({
    required this.value,
    required this.label,
    required this.selected,
  });

  /// `groups[].value` — sent back verbatim as the `group_by` option.
  final String value;

  /// `groups[].label` — the words the segment shows.
  final String label;

  /// `groups[].selected` — true on the grouping this render used.
  ///
  /// Read, never derived: comparing [value] with the payload's `group_by`
  /// here would be the client deciding which segment is lit, and the backend
  /// already said (N-2).
  final bool selected;

  @override
  List<Object?> get props => <Object?>[value, label, selected];
}
