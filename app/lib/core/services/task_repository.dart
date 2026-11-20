import '../models/task_model.dart';
import '../models/free_slot_model.dart';
import '../models/chat_message_model.dart';

abstract class TaskRepository {
  Future<List<TaskModel>> getTasks({DateTime? date});

  Future<TaskModel> getTaskById(String id);

  Future<TaskModel> createTask(TaskModel task);

  Future<TaskModel> updateTask(TaskModel task);

  Future<void> deleteTask(String id);

  Future<List<FreeSlotModel>> getFreeSlots({
    required DateTime date,
    required int durationMinutes,
    required String workStart,
    required String workEnd,
  });

  Future<List<TaskModel>> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeTaskId,
  });

  Future<ChatMessageModel> sendUserMessage(
    String message, {
    bool isVoice = false,
    int? durationSeconds,
    required String currentLocale,
  });

  Future<void> resetDemoData();
}
