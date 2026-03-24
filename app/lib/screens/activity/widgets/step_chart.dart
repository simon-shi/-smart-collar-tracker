import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../config/theme.dart';
import '../../../utils/formatters.dart';

/// A bar chart widget that displays daily step counts over a given period.
/// Highlights the today's bar and shows a goal line if [stepGoal] is provided.
class StepChart extends StatelessWidget {
  /// Daily step counts in chronological order (oldest → newest).
  final List<int> steps;

  /// Day labels corresponding to each [steps] entry (e.g. 'Mon', 'Tue').
  final List<String> labels;

  /// Optional daily step goal to draw a reference line.
  final int? stepGoal;

  /// Height of the chart area. Defaults to 180.
  final double height;

  /// Whether to show today's bar highlighted. Defaults to true.
  final bool highlightToday;

  const StepChart({
    super.key,
    required this.steps,
    required this.labels,
    this.stepGoal,
    this.height = 180,
    this.highlightToday = true,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No step data')),
      );
    }

    final maxSteps =
        (steps.reduce((a, b) => a > b ? a : b)).toDouble() * 1.2;
    final goal = stepGoal?.toDouble();
    final todayIndex = steps.length - 1;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxSteps > 0 ? maxSteps : 1,
          barGroups: steps.asMap().entries.map((e) {
            final isToday = highlightToday && e.key == todayIndex;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: isToday ? AppColors.accent : AppColors.primary,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxSteps,
                    color: AppColors.primary.withOpacity(0.06),
                  ),
                ),
              ],
            );
          }).toList(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxSteps / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: (highlightToday && i == todayIndex)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (highlightToday && i == todayIndex)
                            ? AppColors.accent
                            : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  Formatters.steps(v.toInt()),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          extraLinesData: goal != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: goal,
                    color: AppColors.accent.withOpacity(0.7),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.accent,
                      ),
                      labelResolver: (_) => 'Goal',
                    ),
                  )
                ])
              : null,
        ),
      ),
    );
  }
}
