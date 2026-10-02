import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../bloc/order_ticket_bloc_harness.dart';

/// The order ticket's route.
///
/// It has one of its own because the ticket's options must travel **alone**:
/// the read endpoint applies a single flat option set to every view in a
/// request, so `side` sent beside the portfolio's other views would 422 all
/// of them (N-7, spec `frontend/0006` OD-5). This lives beside the feature
/// rather than in `router/app_router_test.dart`, which was already at the
/// 150-line budget.
void main() {
  group('the order ticket route', () {
    late MockViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
    });

    Future<void> pumpRouter(WidgetTester tester, GoRouter router) =>
        tester.pumpWidget(
          MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<ViewsRepository>.value(value: repository),
              RepositoryProvider<ComponentRegistry>.value(
                value: ComponentRegistry(),
              ),
            ],
            // The real theme, because the card reads `ChartPalette` from it
            // and a bare MaterialApp would hide a missing ThemeExtension.
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        );

    test('exposes its path as a constant', () {
      // The path literal lives in one place, like every other route's.
      expect(AppRoutes.orderTicket, equals('/order-ticket'));
    });

    test('is declared in the router table', () {
      final router = buildRouter();
      final paths = router.configuration.routes.whereType<GoRoute>().map(
        (route) => route.path,
      );
      expect(paths, contains(AppRoutes.orderTicket));
      router.dispose();
    });

    testWidgets('builds the interactive page at that location', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.orderTicket),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderTicketPage), findsOneWidget);
    });
  });
}
