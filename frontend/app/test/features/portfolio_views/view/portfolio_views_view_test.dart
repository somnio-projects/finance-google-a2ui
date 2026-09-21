import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/features/portfolio_views/bloc/portfolio_views_bloc.dart';
import 'package:finance_app/features/portfolio_views/view/portfolio_views_view.dart';
import 'package:finance_core/finance_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockBloc extends MockBloc<PortfolioViewsEvent, PortfolioViewsState>
    implements PortfolioViewsBloc;

void main() {
  group(PortfolioViewsView, () {
    late PortfolioViewsBloc bloc;
    late ComponentRegistry registry;

    setUp(() {
      bloc = _MockBloc();
      registry = ComponentRegistry()
        ..register(const HoldingsAllocationComponent());
    });

    Future<void> pumpView(WidgetTester tester, PortfolioViewsState state) {
      when(() => bloc.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider<PortfolioViewsBloc>.value(
          value: bloc,
          child: const PortfolioViewsView(),
        ),
        componentRegistry: registry,
      );
    }

    testWidgets('shows a spinner while initial', (tester) async {
      await pumpView(tester, const PortfolioViewsState());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a spinner while loading', (tester) async {
      await pumpView(
        tester,
        const PortfolioViewsState(status: PortfolioViewsStatus.loading),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders one component per returned view on success', (
      tester,
    ) async {
      await pumpView(
        tester,
        PortfolioViewsState(
          status: PortfolioViewsStatus.success,
          rendered: renderedViews(),
        ),
      );
      expect(find.byType(HoldingsAllocationCard), findsOneWidget);
      expect(find.text(r'$65,038.60'), findsOneWidget);
    });

    testWidgets('separates the surfaces when several are returned', (
      tester,
    ) async {
      await pumpView(
        tester,
        PortfolioViewsState(
          status: PortfolioViewsStatus.success,
          rendered: renderedViews(
            extraViews: const <String, dynamic>{
              'taxlots.table.v1': <String, dynamic>{'view': 'taxlots.table.v1'},
            },
          ),
        ),
      );
      expect(find.byType(HoldingsAllocationCard), findsOneWidget);
      // The second view has no component in this build, so the host shows
      // its placeholder rather than failing the whole screen.
      expect(find.textContaining('No component for'), findsOneWidget);
    });

    testWidgets('says so when the envelope carried no views', (tester) async {
      await pumpView(
        tester,
        const PortfolioViewsState(status: PortfolioViewsStatus.success),
      );
      expect(find.text('No views were returned.'), findsOneWidget);
    });

    testWidgets('shows the backend safe detail and code on failure', (
      tester,
    ) async {
      await pumpView(
        tester,
        const PortfolioViewsState(
          status: PortfolioViewsStatus.failure,
          failure: ProblemFailure(
            ProblemDetails(
              type: 'https://errors.finance-a2ui/validation-failed',
              title: 'Unprocessable Entity',
              status: 422,
              detail: "view 'x' rejected option(s) ['top_n']",
            ),
          ),
        ),
      );
      expect(
        find.text("view 'x' rejected option(s) ['top_n']"),
        findsOneWidget,
      );
      expect(find.text('validation-failed'), findsOneWidget);
    });

    testWidgets('falls back to generic text when a failure carries none', (
      tester,
    ) async {
      await pumpView(
        tester,
        const PortfolioViewsState(status: PortfolioViewsStatus.failure),
      );
      expect(find.text('The request failed.'), findsOneWidget);
      expect(find.text('unknown'), findsOneWidget);
    });
  });
}
