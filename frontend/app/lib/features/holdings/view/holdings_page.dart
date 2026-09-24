import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Holdings tab: owns its bloc's lifetime (spec frontend/0009).
class HoldingsPage extends StatelessWidget {
  /// Creates the page.
  const HoldingsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<HoldingsBloc>(
    create: (context) =>
        HoldingsBloc(viewsRepository: context.read<ViewsRepository>())
          ..add(const HoldingsRequested()),
    child: const HoldingsView(),
  );
}
