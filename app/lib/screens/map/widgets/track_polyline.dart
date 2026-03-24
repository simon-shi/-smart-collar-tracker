import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/track_point.dart';
import '../../../config/theme.dart';

/// Builds a [Set<Polyline>] from a list of [TrackPoint]s, applying a
/// color gradient from [startColor] to [endColor] to visualise the
/// trajectory direction and, optionally, speed.
class TrackPolyline {
  TrackPolyline._();

  /// Builds a single multi-colour polyline by splitting the track into
  /// segments and assigning an interpolated colour per segment.
  static Set<Polyline> build(
    List<TrackPoint> points, {
    Color startColor = AppColors.accent,
    Color endColor = AppColors.primary,
    int width = 4,
    bool animated = false,
  }) {
    if (points.length < 2) return {};

    final polylines = <Polyline>{};
    final total = points.length - 1;

    for (int i = 0; i < total; i++) {
      final t = total == 1 ? 0.0 : i / (total - 1);
      final color = Color.lerp(startColor, endColor, t) ?? endColor;

      polylines.add(
        Polyline(
          polylineId: PolylineId('track_segment_$i'),
          points: [
            LatLng(points[i].latitude, points[i].longitude),
            LatLng(points[i + 1].latitude, points[i + 1].longitude),
          ],
          color: color,
          width: width,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    return polylines;
  }

  /// Builds a simpler single-colour polyline – useful for live tracking
  /// where colour gradient is not needed.
  static Polyline buildSolid(
    List<TrackPoint> points, {
    Color color = AppColors.primary,
    int width = 4,
  }) {
    return Polyline(
      polylineId: const PolylineId('track_solid'),
      points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      color: color,
      width: width,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
  }
}

/// A widget that renders a track polyline legend showing the gradient
/// direction (start → end).
class TrackPolylineLegend extends StatelessWidget {
  final Color startColor;
  final Color endColor;
  final String startLabel;
  final String endLabel;

  const TrackPolylineLegend({
    super.key,
    this.startColor = AppColors.accent,
    this.endColor = AppColors.primary,
    this.startLabel = 'Start',
    this.endLabel = 'End',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(startLabel,
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
          const SizedBox(width: 6),
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [startColor, endColor]),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(endLabel,
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}
