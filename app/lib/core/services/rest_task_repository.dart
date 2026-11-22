import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';
import '../models/free_slot_model.dart';
import '../models/chat_message_model.dart';
import '../models/user_settings_model.dart';
import '../models/extracted_task_draft_model.dart';
import 'task_repository.dart';
import 'api_client.dart';

class RestTaskRepository implements TaskRepository {
  final Dio _dio;

  RestTaskRepository(this._dio);

  @override
  Future<List<TaskModel>> getTasks({DateTime? date}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) {
        final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
        queryParams['start_date'] = startOfDay.toIso8601String();
        queryParams['end_date'] = endOfDay.toIso8601String();
      }

      final response = await _dio.get('/tasks', queryParameters: queryParams);
      final list = response.data as List<dynamic>;
      return list.map((json) => TaskModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.error is ConflictException) throw e.error!;
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? e.message ?? 'Failed to load tasks')
            : e.message ?? 'Failed to load tasks',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<TaskModel> getTaskById(String id) async {
    try {
      final response = await _dio.get('/tasks/$id');
      return TaskModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Task not found')
            : 'Task not found',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<TaskModel> createTask(TaskModel task, {bool force = false}) async {
    try {
      final body = {
        'title': task.title,
        'description': task.description,
        'startTime': task.startTime.toIso8601String(),
        'endTime': task.endTime.toIso8601String(),
        'priority': task.priority.name,
        'status': task.status.name,
        'remindBeforeMinutes':
            task.reminders.isNotEmpty ? task.reminders.first.offsetMinutes : 30,
        'isVoiceCreated': task.isVoiceCreated,
        'tags': task.tags,
        'recurrenceType': task.recurrenceType,
        'recurrenceDays': task.recurrenceDays,
        'recurrenceEndDate': task.recurrenceEndDate?.toUtc().toIso8601String(),
        'recurrenceCount': task.recurrenceCount,
        'recurrenceGroupId': task.recurrenceGroupId,
        'isRecurrenceActive': task.isRecurrenceActive,
        'force': force,
      };

      final response = await _dio.post('/tasks', data: body);
      return TaskModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ConflictException) {
        throw e.error!;
      }
      final msg = e.response?.data is Map
          ? (e.response?.data['detail']?.toString() ?? 'Failed to create task')
          : 'Failed to create task';
      throw ApiException(message: msg, statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) async {
    try {
      final body = {
        'title': task.title,
        'description': task.description,
        'startTime': task.startTime.toIso8601String(),
        'endTime': task.endTime.toIso8601String(),
        'priority': task.priority.name,
        'status': task.status.name,
        'remindBeforeMinutes':
            task.reminders.isNotEmpty ? task.reminders.first.offsetMinutes : 30,
        'tags': task.tags,
        'recurrenceType': task.recurrenceType,
        'recurrenceDays': task.recurrenceDays,
        'recurrenceEndDate': task.recurrenceEndDate?.toUtc().toIso8601String(),
        'recurrenceCount': task.recurrenceCount,
        'isRecurrenceActive': task.isRecurrenceActive,
        'force': true,
      };

      final response = await _dio.put('/tasks/${task.id}', data: body);
      return TaskModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Failed to update task')
            : 'Failed to update task',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await _dio.delete('/tasks/$id');
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Failed to delete task')
            : 'Failed to delete task',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<TaskModel> toggleTask(String id) async {
    try {
      final response = await _dio.patch('/tasks/$id/toggle');
      return TaskModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to toggle task',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> stopRecurrence(String groupId, {bool deleteFuture = true}) async {
    try {
      final response = await _dio.post(
        '/tasks/recurrence/$groupId/stop',
        queryParameters: {'delete_future': deleteFuture},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['detail']?.toString() ?? 'Failed to stop recurring series')
          : 'Failed to stop recurring series';
      throw ApiException(message: msg, statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<List<FreeSlotModel>> getFreeSlots({
    required DateTime date,
    required int durationMinutes,
    required String workStart,
    required String workEnd,
  }) async {
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final response = await _dio.get(
        '/tasks/free-slots',
        queryParameters: {
          'date': formattedDate,
          'min_duration_minutes': durationMinutes,
        },
      );
      final list = response.data as List<dynamic>;
      return list.map((s) => FreeSlotModel.fromJson(s as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('Error getting free slots: $e');
      return [];
    }
  }

  @override
  Future<List<TaskModel>> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeTaskId,
  }) async {
    try {
      final tasks = await getTasks();
      return tasks.where((t) {
        if (excludeTaskId != null && t.id == excludeTaskId) return false;
        if (t.status == TaskStatus.cancelled) return false;
        return t.startTime.isBefore(endTime) && t.endTime.isAfter(startTime);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ChatMessageModel> sendUserMessage(
    String message, {
    bool isVoice = false,
    int? durationSeconds,
    required String currentLocale,
  }) async {
    try {
      final response = await _dio.post(
        '/assistant/message',
        data: {'text': message},
      );
      final assistantMsgJson = response.data['assistantMessage'] as Map<String, dynamic>;
      return ChatMessageModel.fromJson(assistantMsgJson);
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Assistant failed')
            : 'Assistant failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> sendVoiceMessage({
    required List<int> audioBytes,
    required String filename,
    required String mimeType,
    int? durationSeconds,
  }) async {
    try {
      final map = <String, dynamic>{
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: filename,
        ),
      };
      if (durationSeconds != null) {
        map['duration_seconds'] = durationSeconds;
      }
      final formData = FormData.fromMap(map);

      final response = await _dio.post(
        '/assistant/voice',
        data: formData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Voice assistant failed')
            : 'Voice assistant failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<({String reply, List<ExtractedTaskDraftModel> tasks})> extractTasksFromFile({
    required List<int> fileBytes,
    required String fileName,
    String? instruction,
    String? timezone,
  }) async {
    try {
      final map = <String, dynamic>{
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      };
      if (instruction != null && instruction.trim().isNotEmpty) {
        map['instruction'] = instruction.trim();
      }
      if (timezone != null && timezone.trim().isNotEmpty) {
        map['timezone'] = timezone.trim();
      }
      final formData = FormData.fromMap(map);

      final response = await _dio.post(
        '/tasks/extract-from-file',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? '';
      final rawList = data['extractedTasks'] as List<dynamic>? ?? [];
      final tasks = rawList
          .map((item) => ExtractedTaskDraftModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return (reply: reply, tasks: tasks);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['detail']?.toString() ?? 'Failed to extract tasks from file')
          : (e.message ?? 'Failed to extract tasks from file');
      throw ApiException(message: msg, statusCode: e.response?.statusCode);
    }
  }

  Future<List<TaskModel>> createBatchTasks(List<ExtractedTaskDraftModel> drafts) async {
    try {
      final body = {
        'tasks': drafts.map((d) => d.toTaskCreateJson()).toList(),
      };
      final response = await _dio.post('/tasks/batch', data: body);
      final data = response.data as Map<String, dynamic>;
      final rawTasks = data['tasks'] as List<dynamic>? ?? [];
      return rawTasks
          .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['detail']?.toString() ?? 'Failed to create tasks in batch')
          : (e.message ?? 'Failed to create tasks in batch');
      throw ApiException(message: msg, statusCode: e.response?.statusCode);
    }
  }

  Future<List<ChatMessageModel>> getChatHistory() async {
    try {
      final response = await _dio.get('/assistant/history');
      final list = response.data as List<dynamic>;
      return list.map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('Failed to get chat history: $e');
      return [];
    }
  }

  Future<void> confirmDeleteAction(String taskId) async {
    try {
      await _dio.post('/assistant/actions/confirm-delete/$taskId');
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to confirm delete',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> undoCreateAction(String taskId) async {
    try {
      await _dio.post('/assistant/actions/undo-create/$taskId');
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to undo task creation',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<TaskModel> resolveConflictAction({
    required TaskModel task,
    FreeSlotModel? selectedSlot,
    bool force = false,
  }) async {
    try {
      final body = {
        'task': {
          'title': task.title,
          'description': task.description,
          'startTime': task.startTime.toIso8601String(),
          'endTime': task.endTime.toIso8601String(),
          'priority': task.priority.name,
          'status': task.status.name,
          'remindBeforeMinutes':
              task.reminders.isNotEmpty ? task.reminders.first.offsetMinutes : 30,
          'tags': task.tags,
        },
        if (selectedSlot != null) 'selectedSlot': selectedSlot.toJson(),
        'force': force,
      };

      final response = await _dio.post('/assistant/actions/resolve-conflict', data: body);
      final taskJson = response.data['task'] as Map<String, dynamic>;
      return TaskModel.fromJson(taskJson);
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to resolve conflict',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<UserSettingsModel> getSettings() async {
    try {
      final response = await _dio.get('/settings');
      return UserSettingsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to load user settings',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<UserSettingsModel> updateSettings(UserSettingsModel settings) async {
    try {
      final response = await _dio.put('/settings', data: settings.toJson());
      return UserSettingsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to update user settings',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> resetDemoData() async {
    try {
      final tasks = await getTasks();
      for (final t in tasks) {
        await deleteTask(t.id);
      }
    } catch (_) {}
  }
}

final restTaskRepositoryProvider = Provider<RestTaskRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return RestTaskRepository(dio);
});
