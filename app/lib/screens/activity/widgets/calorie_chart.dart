import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../config/theme.dart';

/// A line chart that displays daily calorie burn over a given period.
class CalorieChart extends StatelessWidget {
  /// Daily calorie values in chronological order (oldest → newest).
  final List<double> calories;

  /// Day labels corresponding to each [calories] entry.
  final List<String> labels;

  /// Optional calorie goal to render as a reference line.
  final double? calorieGoal;

  /// Height of the chart area. Defaults to 180.
  final double height;

  const CalorieChart({
    super.key,
    required this.calories,
    required this.labels,
    this.calorieGoal,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    if (calories.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No calorie data')),
      );
    }

    final maxCal =
        (calories.reduce((a, b) => a > b ? a : b) * 1.25).ceilToDouble();

    final spots = calories
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxCal > 0 ? maxCal : 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              color: AppColors.accent,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.accent,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withOpacity(0.12),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxCal / 4,
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
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()} kcal',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          extraLinesData: calorieGoal != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: calorieGoal!,
                    color: AppColors.primary.withOpacity(0.7),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding:
                          const EdgeInsets.only(right: 4, bottom: 2),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.primary),
                      labelResolver: (_) => 'Goal',
                    ),
                  )
                ])
              : null,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(0)} kcal',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
