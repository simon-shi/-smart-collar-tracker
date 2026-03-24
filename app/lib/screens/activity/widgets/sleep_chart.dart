import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../config/theme.dart';

/// Data class representing a single sleep segment.
class SleepSegment {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  const SleepSegment({
    required this.start,
    required this.end,
    required this.stage,
  });

  Duration get duration => end.difference(start);
}

enum SleepStage { awake, light, deep, rem }

extension SleepStageExt on SleepStage {
  Color get color {
    switch (this) {
      case SleepStage.awake:
        return Colors.orange.shade300;
      case SleepStage.light:
        return AppColors.primaryLight;
      case SleepStage.deep:
        return AppColors.primaryDark;
      case SleepStage.rem:
        return Colors.indigo.shade300;
    }
  }

  String get label {
    switch (this) {
      case SleepStage.awake:
        return 'Awake';
      case SleepStage.light:
        return 'Light';
      case SleepStage.deep:
        return 'Deep';
      case SleepStage.rem:
        return 'REM';
    }
  }
}

/// A stacked horizontal bar chart that visualises sleep stages across the
/// night. Each [SleepSegment] is rendered as a proportional strip.
class SleepChart extends StatelessWidget {
  final List<SleepSegment> segments;

  /// Total sleep duration label shown on the right.
  final Duration? totalSleep;

  /// Height of the chart bar. Defaults to 40.
  final double barHeight;

  const SleepChart({
    super.key,
    required this.segments,
    this.totalSleep,
    this.barHeight = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(
        height: barHeight + 40,
        child: const Center(child: Text('No sleep data')),
      );
    }

    // Calculate total span for proportional widths
    final totalMillis = segments.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMilliseconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stage bar
        LayoutBuilder(builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: segments.map((s) {
                final flex = s.duration.inMilliseconds / totalMillis;
                return Container(
                  width: constraints.maxWidth * flex,
                  height: barHeight,
                  color: s.stage.color,
                );
              }).toList(),
            ),
          );
        }),
        const SizedBox(height: 6),
        // Time axis labels
        _buildTimeAxis(context),
        const SizedBox(height: 12),
        // Summary tiles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStageTile(context, SleepStage.deep,
                _stageDuration(SleepStage.deep).inMinutes),
            _buildStageTile(context, SleepStage.light,
                _stageDuration(SleepStage.light).inMinutes),
            _buildStageTile(context, SleepStage.rem,
                _stageDuration(SleepStage.rem).inMinutes),
            _buildStageTile(context, SleepStage.awake,
                _stageDuration(SleepStage.awake).inMinutes),
          ],
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 16,
          children: SleepStage.values
              .map((s) => _LegendItem(color: s.color, label: s.label))
              .toList(),
        ),
      ],
    );
  }

  Duration _stageDuration(SleepStage stage) {
    return segments
        .where((s) => s.stage == stage)
        .fold(Duration.zero, (sum, s) => sum + s.duration);
  }

  Widget _buildTimeAxis(BuildContext context) {
    if (segments.isEmpty) return const SizedBox();
    final start = segments.first.start;
    final end = segments.last.end;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_formatHour(start),
            style:
                const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(_formatHour(end),
            style:
                const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  String _formatHour(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildStageTile(
      BuildContext context, SleepStage stage, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: stage.color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 2),
        Text(
          h > 0 ? '${h}h ${m}m' : '${m}m',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(stage.label,
            style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
