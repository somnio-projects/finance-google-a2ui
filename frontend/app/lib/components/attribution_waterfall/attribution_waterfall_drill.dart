import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// What a waterfall surface offers a **selected** bucket: the drill.
///
/// Built only when three things hold at once — the surface sits in a
/// [SurfaceActions] scope, the payload declares `drill.attribution.v1`, and
/// the bucket's key is among its `choices` (spec frontend/0040 AC-2). The
/// words on the button are the declaration's own `label`, never a Dart
/// constant: a second name for one action would not follow the view's
/// locale (OD-1).
class WaterfallDrill {
  /// Creates the offer.
  const WaterfallDrill({
    required this.label,
    required this.drivers,
    required this.send,
  });

  /// The id the payload declares the drill under, on both wires.
  static const String declaredAction = 'drill.attribution.v1';

  /// The button's words, as the declaration publishes them.
  final String label;

  /// Every key the declaration accepts.
  final Set<String> drivers;

  /// Sends the drill for one key.
  final ValueChanged<String> send;

  /// Whether the bucket keyed [key] may be drilled.
  bool offers(String key) => drivers.contains(key);

  /// Reads the offer from [payload], sending it as [action] through the
  /// scope above [context]; null when any of the three conditions fails.
  static WaterfallDrill? of(
    BuildContext context,
    ViewPayload payload, {
    required String action,
  }) {
    final scope = SurfaceActions.maybeOf(context);
    if (scope == null) return null;
    for (final declared in payload.rows('actions')) {
      if (declared.text('action') != declaredAction) continue;
      return WaterfallDrill(
        label: declared.text('label'),
        drivers: declared.strings('choices').toSet(),
        send: (key) => scope.onAction(
          SurfaceActionRequest(
            action: action,
            args: <String, String>{'driver': key},
          ),
        ),
      );
    }
    return null;
  }
}
