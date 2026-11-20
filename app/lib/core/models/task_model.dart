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
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get duration => endTime.difference(startTime);

  bool get isCompleted => status == TaskStatus.completed;
  bool get isCancelled => status == TaskStatus.cancelled;

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
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: _parseUtcToLocal(json['startTime']),
      endTime: _parseUtcToLocal(json['endTime']),
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
      isVoiceCreated: json['isVoiceCreated'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: _parseUtcToLocal(json['createdAt']),
      updatedAt: _parseUtcToLocal(json['updatedAt']),
    );
  }
}
