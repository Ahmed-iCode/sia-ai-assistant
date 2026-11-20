enum ReminderType { notification, alarm, email }

class ReminderModel {
  final String id;
  final String taskId;
  final DateTime remindAt;
  final int offsetMinutes;
  final ReminderType type;
  final bool isTriggered;

  const ReminderModel({
    required this.id,
    required this.taskId,
    required this.remindAt,
    this.offsetMinutes = 30,
    this.type = ReminderType.notification,
    this.isTriggered = false,
  });

  ReminderModel copyWith({
    String? id,
    String? taskId,
    DateTime? remindAt,
    int? offsetMinutes,
    ReminderType? type,
    bool? isTriggered,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      remindAt: remindAt ?? this.remindAt,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      type: type ?? this.type,
      isTriggered: isTriggered ?? this.isTriggered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'remindAt': remindAt.toUtc().toIso8601String(),
      'offsetMinutes': offsetMinutes,
      'type': type.name,
      'isTriggered': isTriggered,
    };
  }

  static DateTime _parseUtcToLocal(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    final str = value.toString().trim();
    if (str.isEmpty) return DateTime.now();
    final hasTimezone = str.endsWith('Z') ||
        str.endsWith('z') ||
        RegExp(r'[+-]\d{2}(:\d{2})?$').hasMatch(str);
    final parsed = DateTime.parse(hasTimezone ? str : '${str}Z');
    return parsed.toLocal();
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      remindAt: _parseUtcToLocal(json['remindAt']),
      offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 30,
      type: ReminderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ReminderType.notification,
      ),
      isTriggered: json['isTriggered'] as bool? ?? false,
    );
  }
}
