import 'task_model.dart';
import 'free_slot_model.dart';
import 'extracted_task_draft_model.dart';

enum AiCardType {
  taskCreated,
  conflictAlert,
  freeSlots,
  deleteConfirm,
  batchTasksPreview,
}

class AiActionCardModel {
  final AiCardType type;
  final TaskModel? task;
  final TaskModel? conflictingTask;
  final List<FreeSlotModel> freeSlots;
  final List<ExtractedTaskDraftModel> extractedTasks;
  final String? message;
  final bool isExecuted;
  final bool isUndone;

  const AiActionCardModel({
    required this.type,
    this.task,
    this.conflictingTask,
    this.freeSlots = const [],
    this.extractedTasks = const [],
    this.message,
    this.isExecuted = false,
    this.isUndone = false,
  });

  AiActionCardModel copyWith({
    AiCardType? type,
    TaskModel? task,
    TaskModel? conflictingTask,
    List<FreeSlotModel>? freeSlots,
    List<ExtractedTaskDraftModel>? extractedTasks,
    String? message,
    bool? isExecuted,
    bool? isUndone,
  }) {
    return AiActionCardModel(
      type: type ?? this.type,
      task: task ?? this.task,
      conflictingTask: conflictingTask ?? this.conflictingTask,
      freeSlots: freeSlots ?? this.freeSlots,
      extractedTasks: extractedTasks ?? this.extractedTasks,
      message: message ?? this.message,
      isExecuted: isExecuted ?? this.isExecuted,
      isUndone: isUndone ?? this.isUndone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'task': task?.toJson(),
      'conflictingTask': conflictingTask?.toJson(),
      'freeSlots': freeSlots.map((s) => s.toJson()).toList(),
      'extractedTasks': extractedTasks.map((t) => t.toJson()).toList(),
      'message': message,
      'isExecuted': isExecuted,
      'isUndone': isUndone,
    };
  }

  factory AiActionCardModel.fromJson(Map<String, dynamic> json) {
    return AiActionCardModel(
      type: AiCardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AiCardType.taskCreated,
      ),
      task: json['task'] != null
          ? TaskModel.fromJson(json['task'] as Map<String, dynamic>)
          : null,
      conflictingTask: json['conflictingTask'] != null
          ? TaskModel.fromJson(json['conflictingTask'] as Map<String, dynamic>)
          : null,
      freeSlots: (json['freeSlots'] as List<dynamic>?)
              ?.map((e) => FreeSlotModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      extractedTasks: (json['extractedTasks'] as List<dynamic>?)
              ?.map((e) => ExtractedTaskDraftModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      message: json['message'] as String?,
      isExecuted: json['isExecuted'] as bool? ?? false,
      isUndone: json['isUndone'] as bool? ?? false,
    );
  }
}
