import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/activity_provider.dart';
import '../../../providers/pet_provider.dart';
import '../../../config/theme.dart';
import '../../../utils/formatters.dart';

class ActivitySummaryWidget extends ConsumerWidget {
  final VoidCallback? onTap;

  const ActivitySummaryWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);
    final activityAsync = petId != null
        ? ref.watch(todayActivityProvider(petId))
        : const AsyncValue<dynamic>.data(null);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Activity",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              activityAsync.when(
                data: (activity) {
                  if (activity == null) {
                    return const Text('No activity data available');
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActivityMetric(
                        icon: Icons.directions_walk,
                        value: Formatters.steps(activity.steps),
                        label: 'Steps',
                        color: AppColors.primary,
                      ),
                      _ActivityMetric(
                        icon: Icons.local_fire_department,
                        value: Formatters.calories(activity.caloriesBurned),
                        label: 'Calories',
                        color: AppColors.accent,
                      ),
                      _ActivityMetric(
                        icon: Icons.timer,
                        value: Formatters.duration(
                          Duration(minutes: activity.activeMinutes),
                        ),
                        label: 'Active',
                        color: AppColors.info,
                      ),
                      _ActivityMetric(
                        icon: Icons.bedtime,
                        value: Formatters.duration(
                          Duration(minutes: activity.sleepMinutes),
                        ),
                        label: 'Sleep',
                        color: Colors.indigo,
                      ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Text('Failed to load activity data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ActivityMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
              ),
        ),
      ],
    );
  }
}
