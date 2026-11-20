class UserSettingsModel {
  final String language;
  final String themeMode;
  final String workingHoursStart;
  final String workingHoursEnd;
  final int defaultReminderOffsetMinutes;
  final String timezone;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const UserSettingsModel({
    this.language = 'ar',
    this.themeMode = 'dark',
    this.workingHoursStart = '09:00',
    this.workingHoursEnd = '22:00',
    this.defaultReminderOffsetMinutes = 30,
    this.timezone = 'Africa/Cairo',
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  UserSettingsModel copyWith({
    String? language,
    String? themeMode,
    String? workingHoursStart,
    String? workingHoursEnd,
    int? defaultReminderOffsetMinutes,
    String? timezone,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return UserSettingsModel(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      workingHoursStart: workingHoursStart ?? this.workingHoursStart,
      workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
      defaultReminderOffsetMinutes:
          defaultReminderOffsetMinutes ?? this.defaultReminderOffsetMinutes,
      timezone: timezone ?? this.timezone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'themeMode': themeMode,
      'workingHoursStart': workingHoursStart,
      'workingHoursEnd': workingHoursEnd,
      'defaultReminderOffsetMinutes': defaultReminderOffsetMinutes,
      'timezone': timezone,
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      language: json['language'] as String? ?? 'ar',
      themeMode: json['themeMode'] as String? ?? 'dark',
      workingHoursStart: json['workingHoursStart'] as String? ?? '09:00',
      workingHoursEnd: json['workingHoursEnd'] as String? ?? '22:00',
      defaultReminderOffsetMinutes:
          (json['defaultReminderOffsetMinutes'] as num?)?.toInt() ?? 30,
      timezone: json['timezone'] as String? ?? 'Africa/Cairo',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    );
  }
}
