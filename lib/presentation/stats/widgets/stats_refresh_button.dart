import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/stats/bloc/stats_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StatsRefreshButton extends StatelessWidget {
  const StatsRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.refreshLabel,
      icon: const Icon(Icons.refresh),
      onPressed: () async {
        await context.read<StatsCubit>().refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.statsUpdated)),
          );
        }
      },
    );
  }
}
