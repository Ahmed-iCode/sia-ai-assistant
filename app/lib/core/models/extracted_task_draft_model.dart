import 'package:uuid/uuid.dart';
import 'task_model.dart';

class ExtractedTaskDraftModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final TaskPriority priority;
  final String? category;
  final int? reminderMinutes;
  final bool isSelected;

  ExtractedTaskDraftModel({
    String? id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.priority = TaskPriority.medium,
    this.category,
    this.reminderMinutes = 15,
    this.isSelected = true,
  }) : id = id ?? const Uuid().v4();

  ExtractedTaskDraftModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    TaskPriority? priority,
    String? category,
    int? reminderMinutes,
    bool? isSelected,
  }) {
    return ExtractedTaskDraftModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isSelected: isSelected ?? this.isSelected,
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
      'category': category,
      'reminderMinutes': reminderMinutes,
      'isSelected': isSelected,
    };
  }

  Map<String, dynamic> toTaskCreateJson() {
    return {
      'title': title,
      'description': description,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'priority': priority.name,
      'status': 'pending',
      'remindBeforeMinutes': reminderMinutes ?? 30,
      'isVoiceCreated': false,
      'tags': (category != null && category!.trim().isNotEmpty) ? [category!.trim()] : <String>[],
      'force': true,
    };
  }

  TaskModel toTaskModel() {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      priority: priority,
      status: TaskStatus.pending,
      tags: (category != null && category!.trim().isNotEmpty) ? [category!.trim()] : const [],
      createdAt: now,
      updatedAt: now,
    );
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

  factory ExtractedTaskDraftModel.fromJson(Map<String, dynamic> json) {
    return ExtractedTaskDraftModel(
      id: json['id'] as String?,
      title: (json['title'] as String?)?.trim() ?? '',
      description: json['description'] as String?,
      startTime: _parseUtcToLocal(json['startTime']),
      endTime: _parseUtcToLocal(json['endTime']),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['priority'] as String?)?.toLowerCase(),
        orElse: () => TaskPriority.medium,
      ),
      category: json['category'] as String?,
      reminderMinutes: json['reminderMinutes'] as int? ?? 15,
      isSelected: json['isSelected'] as bool? ?? true,
    );
  }
}
