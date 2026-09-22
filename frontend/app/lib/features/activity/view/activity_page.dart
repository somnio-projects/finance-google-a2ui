import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Activity tab: owns its bloc's lifetime (spec frontend/0009).
class ActivityPage extends StatelessWidget {
  /// Creates the page.
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<ActivityBloc>(
    create: (context) =>
        ActivityBloc(viewsRepository: context.read<ViewsRepository>())
          ..add(const ActivityRequested()),
    child: const ActivityView(),
  );
}
