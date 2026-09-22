import 'package:finance_app/features/home/bloc/home_bloc.dart';
import 'package:finance_app/features/home/view/home_allocation_card.dart';
import 'package:finance_app/features/home/view/home_first_run.dart';
import 'package:finance_app/features/home/view/home_header.dart';
import 'package:finance_app/features/home/view/home_hero.dart';
import 'package:finance_app/features/home/view/home_movers.dart';
import 'package:finance_app/features/home/view/home_questions.dart';
import 'package:finance_app/features/shell/view/session_sheet.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Home tab, section by section as `Home.dc.html` stacks them.
///
/// Header · hero with sparkline and range selector · the allocation card ·
/// suggested questions · top movers. Every string is a payload string; the
/// only words this file owns are the failure fallbacks.
class HomeView extends StatelessWidget {
  /// Creates the view.
  const HomeView({this.onSignOut, super.key});

  /// Called from the avatar's sheet; the page wires it to the session.
  final VoidCallback? onSignOut;

  /// The design's side gutter.
  static const double gutter = 16;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final summary = state.summary;
        if (state.status == HomeStatus.failure) {
          return _Failure(
            message: state.failure?.message ?? 'The request failed.',
          );
        }
        // Before the first payload the page is drawn as shimmer, in its own
        // shape, rather than as a spinner (spec 0015 OD-2).
        if (summary == null) return const HomeFirstRun();
        final allocation = state.allocation;
        return ColoredBox(
          color: tokens.page,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              HomeHeader(
                payload: summary,
                onAccountTap: onSignOut == null
                    ? null
                    : () => showSessionSheet(context, onSignOut: onSignOut!),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: HomeHero(
                  payload: summary,
                  range: state.range,
                  loading: state.status == HomeStatus.loading,
                  onRangeSelected: (range) =>
                      context.read<HomeBloc>().add(HomeRangeChanged(range)),
                ),
              ),
              if (allocation != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
                  child: HomeAllocationCard(payload: allocation),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: HomeQuestions(payload: summary),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 22, gutter, 24),
                child: HomeMovers(payload: summary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      // Shown verbatim: the backend's own safe `detail`, never a stack trace.
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
