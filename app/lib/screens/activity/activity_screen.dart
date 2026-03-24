import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/activity_provider.dart';
import '../../providers/pet_provider.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: petId == null
          ? const Center(child: Text('No pet selected'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Today's summary
                  ref.watch(todayActivityProvider(petId)).when(
                    data: (activity) {
                      if (activity == null) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No activity data today'),
                          ),
                        );
                      }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Today',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        context.push(Routes.activityDetail),
                                    child: const Text('Details'),
                                  ),
                                ],
                              ),
                              // Step progress
                              _StepProgressBar(
                                steps: activity.steps,
                                goal: activity.stepGoal,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _ActivityTile(
                                    icon: Icons.local_fire_department,
                                    value: Formatters.calories(
                                        activity.caloriesBurned),
                                    label: 'Calories',
                                    color: AppColors.accent,
                                  ),
                                  _ActivityTile(
                                    icon: Icons.timer,
                                    value: Formatters.duration(Duration(
                                        minutes: activity.activeMinutes)),
                                    label: 'Active',
                                    color: AppColors.primary,
                                  ),
                                  _ActivityTile(
                                    icon: Icons.bedtime,
                                    value: Formatters.duration(Duration(
                                        minutes: activity.sleepMinutes)),
                                    label: 'Sleep',
                                    color: Colors.indigo,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const Card(child: LinearProgressIndicator()),
                    error: (_, __) =>
                        const Card(child: Text('Failed to load')),
                  ),
                  const SizedBox(height: 16),
                  // Weekly steps chart
                  ref.watch(weeklyActivityProvider(petId)).when(
                    data: (activities) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Steps',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  barGroups: activities
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => BarChartGroupData(
                                          x: e.key,
                                          barRods: [
                                            BarChartRodData(
                                              toY: e.value.steps.toDouble(),
                                              color: AppColors.primary,
                                              width: 16,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (v, _) => Text(
                                          _dayLabel(v.toInt(), activities.length),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () =>
                        const Card(child: LinearProgressIndicator()),
                    error: (_, __) =>
                        const Card(child: Text('Failed to load')),
                  ),
                ],
              ),
            ),
    );
  }

  String _dayLabel(int index, int total) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    if (index < 0 || index >= total) return '';
    final today = DateTime.now().weekday - 1;
    return days[(today - (total - 1 - index)).remainder(7)];
  }
}

class _StepProgressBar extends StatelessWidget {
  final int steps;
  final int goal;

  const _StepProgressBar({required this.steps, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 4),
                Text(
                  Formatters.steps(steps),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            Text(
              'Goal: ${Formatters.steps(goal)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ActivityTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
      ],
    );
  }
}
