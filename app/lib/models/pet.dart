import 'package:equatable/equatable.dart';

enum PetType { dog, cat, other }
enum PetGender { male, female, unknown }

class Pet extends Equatable {
  final String id;
  final String name;
  final PetType type;
  final String breed;
  final PetGender gender;
  final DateTime birthDate;
  final double weightKg;
  final String? photoUrl;
  final String? deviceId;
  final String ownerId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Pet({
    required this.id,
    required this.name,
    required this.type,
    required this.breed,
    required this.gender,
    required this.birthDate,
    required this.weightKg,
    this.photoUrl,
    this.deviceId,
    required this.ownerId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  int get ageMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  }

  String get ageDisplay {
    final months = ageMonths;
    if (months < 12) return '${months}mo';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem > 0 ? '${years}y ${rem}mo' : '${years}y';
  }

  Pet copyWith({
    String? id,
    String? name,
    PetType? type,
    String? breed,
    PetGender? gender,
    DateTime? birthDate,
    double? weightKg,
    String? photoUrl,
    String? deviceId,
    String? ownerId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      weightKg: weightKg ?? this.weightKg,
      photoUrl: photoUrl ?? this.photoUrl,
      deviceId: deviceId ?? this.deviceId,
      ownerId: ownerId ?? this.ownerId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PetType.dog,
      ),
      breed: json['breed'] as String? ?? '',
      gender: PetGender.values.firstWhere(
        (e) => e.name == json['gender'],
        orElse: () => PetGender.unknown,
      ),
      birthDate: DateTime.parse(json['birthDate'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
      photoUrl: json['photoUrl'] as String?,
      deviceId: json['deviceId'] as String?,
      ownerId: json['ownerId'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'breed': breed,
      'gender': gender.name,
      'birthDate': birthDate.toIso8601String(),
      'weightKg': weightKg,
      'photoUrl': photoUrl,
      'deviceId': deviceId,
      'ownerId': ownerId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, type, breed, weightKg, deviceId];
}
