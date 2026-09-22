import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'order_ticket_v2_harness.dart';

/// The multi-leg ticket's route — its own, for the reason v1 has one: `legs`
/// is no other view's option, and the read endpoint applies one flat option
/// set to every view in a request (N-7).
void main() {
  group('the multi-leg ticket route', () {
    late MockViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      stubFetch(repository, Ok<RenderedViews>(ticketV2Envelope()));
    });

    test('exposes its path as a constant', () {
      expect(AppRoutes.orderTicketV2, equals('/order-ticket-v2'));
    });

    test('is declared in the router table', () {
      final router = buildRouter();
      final paths = router.configuration.routes.whereType<GoRoute>().map(
        (route) => route.path,
      );
      expect(paths, contains(AppRoutes.orderTicketV2));
      router.dispose();
    });

    testWidgets('builds the interactive page at that location', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = buildRouter(initialLocation: AppRoutes.orderTicketV2);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: <RepositoryProvider<dynamic>>[
            RepositoryProvider<ViewsRepository>.value(value: repository),
            RepositoryProvider<ComponentRegistry>.value(
              value: ComponentRegistry(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderTicketV2Page), findsOneWidget);
      router.dispose();
    });
  });
}
