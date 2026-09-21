import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Renders exactly one registered view id.
///
/// A component owns both halves of its contract: which [viewId] it serves and
/// how that payload becomes a widget. Nothing outside the component knows the
/// shape of its payload, which is what makes the seventh component an addition
/// rather than an edit (ADR-L D-3, mirroring ADR-K D-15).
///
/// Implementations are `const`-constructible and stateless: a component is a
/// description of a binding, not a place to keep state.
abstract class ViewComponent {
  /// Allows subclasses to declare `const` constructors.
  const ViewComponent();

  /// The frozen view id this component binds, e.g. `holdings.allocation.v1`.
  ///
  /// It is a literal in the component's own module and appears nowhere else —
  /// no enum, no switch, no central list (N-6).
  String get viewId;

  /// The A2UI component type the backend's catalog names for [viewId], e.g.
  /// `AllocationSummary`. Recorded so a reader can line this class up
  /// against the catalog entry it implements.
  String get a2uiComponent;

  /// Builds the widget for [payload].
  ///
  /// Every string bound here is a value the backend already formatted. An
  /// implementation that formats, computes, re-orders or derives anything
  /// breaks the contract (N-1, N-2, N-3, N-10);
  /// `app/test/architecture/binding_rules_test.dart` fails the gate on the
  /// mechanisms that would let it.
  ///
  /// May throw [PayloadContractException] when the payload omits a field the
  /// component binds; the host catches it and shows the violation.
  Widget build(BuildContext context, ViewPayload payload);
}
