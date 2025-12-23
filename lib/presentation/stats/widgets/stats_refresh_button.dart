import 'package:elfouad_admin/presentation/stats/state/stats_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class StatsRefreshButton extends ConsumerWidget {
  const StatsRefreshButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: AppStrings.refreshLabel,
      icon: const Icon(Icons.refresh),
      onPressed: () async {
        await refreshStatsProviders(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text(AppStrings.statsUpdated)));
        }
      },
    );
  }
}
