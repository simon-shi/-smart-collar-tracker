import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/activity_provider.dart';
import '../../providers/pet_provider.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({super.key});

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: petId == null
          ? const Center(child: Text('No pet selected'))
          : TabBarView(
              controller: _tabController,
              children: [
                _DailyView(petId: petId),
                _WeeklyView(petId: petId),
                _MonthlyView(petId: petId),
              ],
            ),
    );
  }
}

class _DailyView extends ConsumerWidget {
  final String petId;
  const _DailyView({required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(todayActivityProvider(petId)).when(
          data: (activity) {
            if (activity == null) {
              return const Center(child: Text('No data for today'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  title: 'Steps',
                  child: _StepChart(steps: activity.steps, goal: activity.stepGoal),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Activity Breakdown',
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: activity.activeMinutes.toDouble(),
                            title: 'Active',
                            color: AppColors.primary,
                            radius: 60,
                          ),
                          PieChartSectionData(
                            value: activity.restMinutes.toDouble(),
                            title: 'Rest',
                            color: Colors.blue[200]!,
                            radius: 60,
                          ),
                          PieChartSectionData(
                            value: activity.playMinutes.toDouble(),
                            title: 'Play',
                            color: AppColors.accent,
                            radius: 60,
                          ),
                          PieChartSectionData(
                            value: activity.sleepMinutes.toDouble(),
                            title: 'Sleep',
                            color: Colors.indigo[300]!,
                            radius: 60,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load')),
        );
  }
}

class _WeeklyView extends ConsumerWidget {
  final String petId;
  const _WeeklyView({required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(weeklyActivityProvider(petId)).when(
          data: (activities) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Weekly Steps',
                child: SizedBox(
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
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load')),
        );
  }
}

class _MonthlyView extends ConsumerWidget {
  final String petId;
  const _MonthlyView({required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(monthlyActivityProvider(petId)).when(
          data: (activities) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Monthly Steps Trend',
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: activities
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  e.value.steps.toDouble(),
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: AppColors.primary,
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ],
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load')),
        );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepChart extends StatelessWidget {
  final int steps;
  final int goal;

  const _StepChart({required this.steps, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      value: steps.toDouble().clamp(0.0, goal.toDouble()),
                      color: AppColors.primary,
                      radius: 20,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: (goal - steps).clamp(0.0, goal.toDouble()),
                      color: AppColors.primary.withOpacity(0.1),
                      radius: 20,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.steps(steps),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text('steps', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal: ${Formatters.steps(goal)}'),
            Text('Progress: ${(steps / goal * 100).toStringAsFixed(0)}%'),
            if (steps >= goal)
              const Chip(
                label: Text('🎉 Goal Reached!'),
                backgroundColor: Color(0xFFE8F5E9),
              ),
          ],
        ),
      ],
    );
  }
}
