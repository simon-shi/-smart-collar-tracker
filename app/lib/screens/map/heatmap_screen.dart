import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../providers/location_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  GoogleMapController? _mapController;
  Set<Circle> _heatCircles = {};

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(locationHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Heatmap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(locationHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const LoadingOverlay(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (points) {
          _heatCircles = points
              .map(
                (p) => Circle(
                  circleId: CircleId(p.id),
                  center: LatLng(p.latitude, p.longitude),
                  radius: 30,
                  fillColor: Colors.red.withOpacity(0.15),
                  strokeColor: Colors.transparent,
                  strokeWidth: 0,
                ),
              )
              .toSet();

          final initial = points.isNotEmpty
              ? CameraPosition(
                  target: LatLng(points.first.latitude, points.first.longitude),
                  zoom: 14,
                )
              : const CameraPosition(target: LatLng(37.7749, -122.4194), zoom: 12);

          return GoogleMap(
            initialCameraPosition: initial,
            onMapCreated: (c) => _mapController = c,
            circles: _heatCircles,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          );
        },
      ),
    );
  }
}
