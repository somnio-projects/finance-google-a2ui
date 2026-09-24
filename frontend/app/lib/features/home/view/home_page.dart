import 'package:finance_app/features/home/bloc/home_bloc.dart';
import 'package:finance_app/features/home/view/home_view.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Home tab: owns its bloc and asks for both views on arrival.
class HomePage extends StatelessWidget {
  /// Creates the page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<HomeBloc>(
    create: (context) =>
        HomeBloc(viewsRepository: context.read<ViewsRepository>())
          ..add(const HomeRequested()),
    child: HomeView(onSignOut: () => context.read<AuthRepository>().signOut()),
  );
}
