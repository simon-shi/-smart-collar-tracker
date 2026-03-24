import 'package:equatable/equatable.dart';

class TrackPoint extends Equatable {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed;
  final double? accuracy;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.accuracy,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      speed: (json['speed'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'accuracy': accuracy,
    };
  }

  @override
  List<Object?> get props => [latitude, longitude, timestamp];
}
