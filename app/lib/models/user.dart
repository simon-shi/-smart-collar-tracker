import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final bool emailVerified;
  final bool biometricEnabled;
  final String preferredUnit; // 'metric', 'imperial'
  final String language; // 'en', 'zh'
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.emailVerified = false,
    this.biometricEnabled = false,
    this.preferredUnit = 'metric',
    this.language = 'en',
    required this.createdAt,
    this.lastLoginAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    bool? emailVerified,
    bool? biometricEnabled,
    String? preferredUnit,
    String? language,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailVerified: emailVerified ?? this.emailVerified,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      preferredUnit: preferredUnit ?? this.preferredUnit,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      preferredUnit: json['preferredUnit'] as String? ?? 'metric',
      language: json['language'] as String? ?? 'en',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'emailVerified': emailVerified,
      'biometricEnabled': biometricEnabled,
      'preferredUnit': preferredUnit,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, email, displayName];
}
