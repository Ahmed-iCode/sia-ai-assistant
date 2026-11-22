import 'reminder_model.dart';

enum TaskPriority { urgent, high, medium, low }

enum TaskStatus { pending, inProgress, completed, cancelled }

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final TaskPriority priority;
  final TaskStatus status;
  final List<ReminderModel> reminders;
  final bool isVoiceCreated;
  final List<String> tags;
  final String recurrenceType;
  final List<String> recurrenceDays;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final String? recurrenceGroupId;
  final bool isRecurrenceActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.reminders = const [],
    this.isVoiceCreated = false,
    this.tags = const [],
    this.recurrenceType = 'none',
    this.recurrenceDays = const [],
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.recurrenceGroupId,
    this.isRecurrenceActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get duration => endTime.difference(startTime);

  bool get isCompleted => status == TaskStatus.completed;
  bool get isCancelled => status == TaskStatus.cancelled;
  bool get isRecurring => recurrenceType != 'none';

  bool overlapsWith(DateTime start, DateTime end) {
    return startTime.isBefore(end) && endTime.isAfter(start);
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    TaskPriority? priority,
    TaskStatus? status,
    List<ReminderModel>? reminders,
    bool? isVoiceCreated,
    List<String>? tags,
    String? recurrenceType,
    List<String>? recurrenceDays,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    String? recurrenceGroupId,
    bool? isRecurrenceActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      reminders: reminders ?? this.reminders,
      isVoiceCreated: isVoiceCreated ?? this.isVoiceCreated,
      tags: tags ?? this.tags,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      isRecurrenceActive: isRecurrenceActive ?? this.isRecurrenceActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'isVoiceCreated': isVoiceCreated,
      'tags': tags,
      'recurrenceType': recurrenceType,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate': recurrenceEndDate?.toUtc().toIso8601String(),
      'recurrenceCount': recurrenceCount,
      'recurrenceGroupId': recurrenceGroupId,
      'isRecurrenceActive': isRecurrenceActive,
      // Snake case aliases for compatibility
      'recurrence_type': recurrenceType,
      'recurrence_days': recurrenceDays,
      'recurrence_end_date': recurrenceEndDate?.toUtc().toIso8601String(),
      'recurrence_count': recurrenceCount,
      'recurrence_group_id': recurrenceGroupId,
      'is_recurrence_active': isRecurrenceActive,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
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

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['recurrenceType'] ?? json['recurrence_type'];
    final rawDays = json['recurrenceDays'] ?? json['recurrence_days'];
    final rawEndDate = json['recurrenceEndDate'] ?? json['recurrence_end_date'];
    final rawCount = json['recurrenceCount'] ?? json['recurrence_count'];
    final rawGroupId = json['recurrenceGroupId'] ?? json['recurrence_group_id'];
    final rawActive = json['isRecurrenceActive'] ?? json['is_recurrence_active'];

    DateTime? parsedEndDate;
    if (rawEndDate != null) {
      parsedEndDate = _parseUtcToLocal(rawEndDate);
    }

    List<String> parsedDays = [];
    if (rawDays is List) {
      parsedDays = rawDays.map((e) => e.toString().toLowerCase()).toList();
    } else if (rawDays is String && rawDays.isNotEmpty) {
      parsedDays = rawDays
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: _parseUtcToLocal(json['startTime'] ?? json['start_time']),
      endTime: _parseUtcToLocal(json['endTime'] ?? json['end_time']),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((e) => ReminderModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isVoiceCreated: (json['isVoiceCreated'] ?? json['is_voice_created']) as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      recurrenceType: (rawType as String?) ?? 'none',
      recurrenceDays: parsedDays,
      recurrenceEndDate: parsedEndDate,
      recurrenceCount: rawCount as int?,
      recurrenceGroupId: rawGroupId as String?,
      isRecurrenceActive: (rawActive as bool?) ?? true,
      createdAt: _parseUtcToLocal(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseUtcToLocal(json['updatedAt'] ?? json['updated_at']),
    );
  }
}
