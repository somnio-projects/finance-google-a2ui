import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A card's live thumbnail: the **real** component, bound to the example
/// payload the backend publishes, laid out at [layoutWidth] and scaled to the
/// card. Nothing is redrawn as a picture — a thumbnail that looked like the
/// component would drift the day the component changed.
class CatalogThumbnail extends StatelessWidget {
  /// Creates the thumbnail of [payload].
  const CatalogThumbnail({required this.payload, super.key});

  /// The height of the well the design gives a thumbnail.
  static const double height = 118;

  /// The width the component is laid out at before scaling — a phone card.
  static const double layoutWidth = 380;

  /// The example payload, verbatim from the catalog entry.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    // Taps stay with the card: a live component in a thumbnail must not
    // swallow the click that opens its page.
    child: IgnorePointer(
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: layoutWidth,
          child: ComponentHost(
            registry: context.read<ComponentRegistry>(),
            payload: payload,
          ),
        ),
      ),
    ),
  );
}
