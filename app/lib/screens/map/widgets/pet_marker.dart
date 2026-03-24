import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../models/pet.dart';
import '../../../../config/theme.dart';

/// Returns a [BitmapDescriptor] factory for the custom pet marker.
/// In production this would render the pet photo to a bitmap; here
/// we build a simple coloured dot marker synchronously.
class PetMarker {
  PetMarker._();

  /// Build a basic [Marker] for [pet] at [position].
  static Marker build({
    required Pet pet,
    required LatLng position,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: MarkerId('pet_${pet.id}'),
      position: position,
      infoWindow: InfoWindow(
        title: pet.name,
        snippet: pet.breed.isNotEmpty ? pet.breed : null,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      onTap: onTap,
    );
  }

  /// Builds a Flutter widget that can be used as an overlay label.
  static Widget label(Pet pet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                pet.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 2,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
