import 'package:equatable/equatable.dart';

class PetLocation extends Equatable {
  final String id;
  final String petId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final String source; // 'gps', 'ble', 'network'
  final DateTime timestamp;

  const PetLocation({
    required this.id,
    required this.petId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.source = 'gps',
    required this.timestamp,
  });

  factory PetLocation.fromJson(Map<String, dynamic> json) {
    return PetLocation(
      id: json['id'] as String,
      petId: json['petId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'gps',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'source': source,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, latitude, longitude, timestamp];
}
