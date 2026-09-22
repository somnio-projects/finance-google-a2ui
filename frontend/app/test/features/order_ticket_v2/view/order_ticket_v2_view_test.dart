import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_page.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_view.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket_v2/order_ticket_v2_harness.dart';
import '../../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

/// What the surface renders in each state. The edit round trip is in
/// `order_ticket_v2_edit_test.dart`.
void main() {
  group(OrderTicketV2View, () {
    late MockViewsRepository repository;

    setUp(() => repository = MockViewsRepository());

    Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
      const OrderTicketV2Page(),
      viewsRepository: repository,
      surfaceSize: const Size(800, 1600),
    );

    testWidgets('requests the v2 view alone and renders it', (tester) async {
      // N-7: `legs` is no other view's option, so the request carries one id
      // — the one the catalog publishes for this component.
      stubFetch(repository, Ok<RenderedViews>(ticketV2Envelope()));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.byType(OrderTicketV2Card), findsOneWidget);
      expect(
        find.text(ticketV2Example()['disclosure']! as String),
        findsOneWidget,
      );
      final captured = verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: captureAny(named: 'views'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, equals(<String>[ticketV2ViewId()]));
    });

    testWidgets('draws the component skeleton before anything arrives', (
      tester,
    ) async {
      stubFetch(repository, Ok<RenderedViews>(ticketV2Envelope()));
      await pumpPage(tester);
      // The component's own `skeleton()`, through the seam it already has —
      // not a Material spinner (spec 0015 OD-3, 0020 AC-7).
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the failure when the first request never lands', (
      tester,
    ) async {
      // The backend's own safe message, never a stack trace.
      stubFetch(
        repository,
        const Err<RenderedViews>(TransportFailure('the server is down')),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.text('the server is down'), findsOneWidget);
      expect(find.byType(OrderTicketV2Card), findsNothing);
    });

    testWidgets('shows a contract violation naming the path', (tester) async {
      // N-3: a missing field is shown, not reconstructed.
      stubFetch(
        repository,
        Ok<RenderedViews>(
          ticketV2Envelope(example: ticketV2ExampleWithout('impact')),
        ),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('impact'), findsOneWidget);
      expect(find.byType(OrderTicketV2Card), findsNothing);
    });

    testWidgets('falls back to a generic line when a rejection has no text', (
      tester,
    ) async {
      stubFetch(
        repository,
        Ok<RenderedViews>(
          RenderedViews.fromJson(const <String, dynamic>{
            'as_of': '2026-09-22T00:00:00Z',
            'portfolio_id': 'current',
            'views': <String, dynamic>{},
          }),
        ),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.byType(OrderTicketV2Card), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });
}
