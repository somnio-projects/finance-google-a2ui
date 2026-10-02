import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

import '../../helpers/catalog_snapshot.dart';

/// What a host recorded when the toggle asked it to re-request.
typedef SentOption = ({String option, String value});

/// The widest the card is pumped at — the catalog board, not a phone.
const Size desktopSurface = Size(1000, 900);

/// The backend's published example, bound through the component under test.
AllocationData allocationData() => const HoldingsAllocationComponent().read(
  ViewPayload.fromJson(CatalogSnapshot.load().exampleFor('HoldingsSummary')),
);

/// The card inside a host that **can** re-request, recording what it asked.
///
/// Built through the component's own `build` rather than by constructing the
/// card, because the thing under test is the seam between them: a component
/// that stopped reading `SurfaceEdits` would still render a card here.
Widget editableAllocation(List<SentOption> sent) => Center(
  child: SurfaceEdits(
    onOptionChanged: (option, value) =>
        sent.add((option: option, value: value)),
    child: Builder(
      builder: (context) => const HoldingsAllocationComponent().build(
        context,
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleFor('HoldingsSummary'),
        ),
      ),
    ),
  ),
);
