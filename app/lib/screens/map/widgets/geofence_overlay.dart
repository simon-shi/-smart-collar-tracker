import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/geofence.dart';

/// Converts a hex color string (e.g. '#4CAF50') to a [Color].
Color _hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// Builds Google Maps [Circle] and [Polygon] overlays from a list of
/// [Geofence] objects.
class GeofenceOverlay {
  GeofenceOverlay._();

  /// Returns a [Set<Circle>] for all circle-shaped geofences.
  static Set<Circle> buildCircles(
    List<Geofence> geofences, {
    void Function(Geofence)? onTap,
  }) {
    return {
      for (final fence in geofences)
        if (fence.isCircle &&
            fence.centerLatitude != null &&
            fence.centerLongitude != null &&
            fence.radiusMeters != null)
          Circle(
            circleId: CircleId('geofence_${fence.id}'),
            center: LatLng(fence.centerLatitude!, fence.centerLongitude!),
            radius: fence.radiusMeters!,
            fillColor: _hexToColor(fence.color).withOpacity(0.15),
            strokeColor: _hexToColor(fence.color).withOpacity(0.8),
            strokeWidth: 2,
            onTap: onTap != null ? () => onTap(fence) : null,
          ),
    };
  }

  /// Returns a [Set<Polygon>] for all polygon-shaped geofences.
  static Set<Polygon> buildPolygons(
    List<Geofence> geofences, {
    void Function(Geofence)? onTap,
  }) {
    return {
      for (final fence in geofences)
        if (fence.isPolygon &&
            fence.vertices != null &&
            fence.vertices!.length >= 3)
          Polygon(
            polygonId: PolygonId('geofence_${fence.id}'),
            points: fence.vertices!
                .map((v) => LatLng(v.latitude, v.longitude))
                .toList(),
            fillColor: _hexToColor(fence.color).withOpacity(0.15),
            strokeColor: _hexToColor(fence.color).withOpacity(0.8),
            strokeWidth: 2,
            onTap: onTap != null ? () => onTap(fence) : null,
          ),
    };
  }

  /// Returns a label marker for the center of a geofence.
  static Marker? buildLabel(Geofence fence) {
    LatLng? center;
    if (fence.isCircle &&
        fence.centerLatitude != null &&
        fence.centerLongitude != null) {
      center = LatLng(fence.centerLatitude!, fence.centerLongitude!);
    } else if (fence.isPolygon &&
        fence.vertices != null &&
        fence.vertices!.isNotEmpty) {
      final avgLat =
          fence.vertices!.map((v) => v.latitude).reduce((a, b) => a + b) /
              fence.vertices!.length;
      final avgLon =
          fence.vertices!.map((v) => v.longitude).reduce((a, b) => a + b) /
              fence.vertices!.length;
      center = LatLng(avgLat, avgLon);
    }
    if (center == null) return null;

    return Marker(
      markerId: MarkerId('geofence_label_${fence.id}'),
      position: center,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        fence.isActive
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueAzure,
      ),
      infoWindow: InfoWindow(
        title: fence.name,
        snippet: fence.isCircle
            ? 'Radius: ${fence.radiusMeters?.toStringAsFixed(0)} m'
            : 'Polygon (${fence.vertices?.length ?? 0} points)',
      ),
    );
  }
}

/// A stateless widget that renders geofence overlays on top of a
/// [GoogleMap]. Wrap your [GoogleMap] with this or pass its output sets
/// directly into [GoogleMap.circles] / [GoogleMap.polygons].
class GeofenceOverlayWidget extends StatelessWidget {
  final List<Geofence> geofences;
  final Widget child;
  final void Function(Geofence)? onGeofenceTap;

  const GeofenceOverlayWidget({
    super.key,
    required this.geofences,
    required this.child,
    this.onGeofenceTap,
  });

  @override
  Widget build(BuildContext context) => child;

  Set<Circle> get circles =>
      GeofenceOverlay.buildCircles(geofences, onTap: onGeofenceTap);

  Set<Polygon> get polygons =>
      GeofenceOverlay.buildPolygons(geofences, onTap: onGeofenceTap);

  Set<Marker> get labels => {
        for (final fence in geofences)
          if (GeofenceOverlay.buildLabel(fence) != null)
            GeofenceOverlay.buildLabel(fence)!,
      };
}
