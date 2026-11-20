import 'user_settings_model.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final bool isActive;
  final UserSettingsModel settings;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.isActive = true,
    this.settings = const UserSettingsModel(),
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? isActive,
    UserSettingsModel? settings,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isActive': isActive,
      'settings': settings.toJson(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      settings: json['settings'] != null
          ? UserSettingsModel.fromJson(json['settings'] as Map<String, dynamic>)
          : const UserSettingsModel(),
    );
  }
}
