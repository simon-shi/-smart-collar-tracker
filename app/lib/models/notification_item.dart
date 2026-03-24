import 'package:equatable/equatable.dart';

enum NotificationType {
  geofenceEnter,
  geofenceExit,
  healthAnomaly,
  lowBattery,
  deviceDisconnected,
  activityGoal,
  firmwareUpdate,
  general,
}

class NotificationItem extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime timestamp;
  final String? petId;
  final String? imageUrl;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.isRead = false,
    required this.timestamp,
    this.petId,
    this.imageUrl,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? timestamp,
    String? petId,
    String? imageUrl,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      petId: petId ?? this.petId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: json['isRead'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      petId: json['petId'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'data': data,
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
      'petId': petId,
      'imageUrl': imageUrl,
    };
  }

  @override
  List<Object?> get props => [id, type, timestamp, isRead];
}
