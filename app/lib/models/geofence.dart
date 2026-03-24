import 'package:equatable/equatable.dart';

enum GeofenceShape { circle, polygon }
enum GeofenceStatus { active, inactive }

class Geofence extends Equatable {
  final String id;
  final String petId;
  final String name;
  final GeofenceShape shape;
  final GeofenceStatus status;
  final String color; // hex color string
  final bool alertOnEnter;
  final bool alertOnExit;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Circle fields
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusMeters;

  // Polygon fields
  final List<GeofencePoint>? vertices;

  const Geofence({
    required this.id,
    required this.petId,
    required this.name,
    required this.shape,
    this.status = GeofenceStatus.active,
    this.color = '#4CAF50',
    this.alertOnEnter = true,
    this.alertOnExit = true,
    required this.createdAt,
    required this.updatedAt,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusMeters,
    this.vertices,
  });

  bool get isCircle => shape == GeofenceShape.circle;
  bool get isPolygon => shape == GeofenceShape.polygon;
  bool get isActive => status == GeofenceStatus.active;

  Geofence copyWith({
    String? id,
    String? petId,
    String? name,
    GeofenceShape? shape,
    GeofenceStatus? status,
    String? color,
    bool? alertOnEnter,
    bool? alertOnExit,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusMeters,
    List<GeofencePoint>? vertices,
  }) {
    return Geofence(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      name: name ?? this.name,
      shape: shape ?? this.shape,
      status: status ?? this.status,
      color: color ?? this.color,
      alertOnEnter: alertOnEnter ?? this.alertOnEnter,
      alertOnExit: alertOnExit ?? this.alertOnExit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      vertices: vertices ?? this.vertices,
    );
  }

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as String,
      petId: json['petId'] as String,
      name: json['name'] as String,
      shape: GeofenceShape.values.firstWhere(
        (e) => e.name == json['shape'],
        orElse: () => GeofenceShape.circle,
      ),
      status: GeofenceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GeofenceStatus.active,
      ),
      color: json['color'] as String? ?? '#4CAF50',
      alertOnEnter: json['alertOnEnter'] as bool? ?? true,
      alertOnExit: json['alertOnExit'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      centerLatitude: (json['centerLatitude'] as num?)?.toDouble(),
      centerLongitude: (json['centerLongitude'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble(),
      vertices: (json['vertices'] as List<dynamic>?)
          ?.map((e) => GeofencePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'name': name,
      'shape': shape.name,
      'status': status.name,
      'color': color,
      'alertOnEnter': alertOnEnter,
      'alertOnExit': alertOnExit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
      'vertices': vertices?.map((v) => v.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, name, shape, status];
}

class GeofencePoint extends Equatable {
  final double latitude;
  final double longitude;

  const GeofencePoint({
    required this.latitude,
    required this.longitude,
  });

  factory GeofencePoint.fromJson(Map<String, dynamic> json) {
    return GeofencePoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  @override
  List<Object?> get props => [latitude, longitude];
}

class GeofenceEvent extends Equatable {
  final String id;
  final String geofenceId;
  final String petId;
  final String eventType; // 'enter', 'exit'
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const GeofenceEvent({
    required this.id,
    required this.geofenceId,
    required this.petId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      id: json['id'] as String,
      geofenceId: json['geofenceId'] as String,
      petId: json['petId'] as String,
      eventType: json['eventType'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'geofenceId': geofenceId,
      'petId': petId,
      'eventType': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, geofenceId, eventType, timestamp];
}
