import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_model.dart';
import '../models/free_slot_model.dart';
import 'api_config.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ConflictException implements Exception {
  final String message;
  final TaskModel? conflictingTask;
  final Map<String, dynamic>? proposedTaskData;
  final List<FreeSlotModel> alternativeFreeSlots;

  const ConflictException({
    required this.message,
    this.conflictingTask,
    this.proposedTaskData,
    this.alternativeFreeSlots = const [],
  });

  @override
  String toString() => 'ConflictException: $message';
}

/// Signal provider incremented when a 401 Unauthorized response is intercepted.
/// Used by [authProvider] to automatically reset auth state and redirect to login.
final authExpiredSignalProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 65),
      receiveTimeout: const Duration(seconds: 65),
      sendTimeout: const Duration(seconds: 65),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await StorageService.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        final path = error.requestOptions.path;
        final isAuthEndpoint = path.contains('/auth/login') || path.contains('/auth/register');

        if (error.response?.statusCode == 401 && !isAuthEndpoint) {
          try {
            await StorageService.remove('auth_token');
            await StorageService.remove('auth_user_data');
          } catch (_) {}
          // Notify auth system of session expiration
          ref.read(authExpiredSignalProvider.notifier).state++;
        }

        // Parse 409 Conflict with structured ConflictDetail
        if (error.response?.statusCode == 409 && error.response?.data != null) {
          try {
            final data = error.response!.data;
            final detail = data is Map ? data['detail'] : null;
            if (detail is Map) {
              final conflictingTaskJson = detail['conflictingTask'] as Map<String, dynamic>?;
              final proposedJson = detail['proposedTask'] as Map<String, dynamic>?;
              final freeSlotsJson = detail['alternativeFreeSlots'] as List<dynamic>?;

              final conflicting = conflictingTaskJson != null
                  ? TaskModel.fromJson(conflictingTaskJson)
                  : null;

              final freeSlots = freeSlotsJson != null
                  ? freeSlotsJson
                      .map((s) => FreeSlotModel.fromJson(s as Map<String, dynamic>))
                      .toList()
                  : <FreeSlotModel>[];

              final msg = detail['message'] as String? ?? 'Schedule conflict detected';

              return handler.reject(
                DioException(
                  requestOptions: error.requestOptions,
                  response: error.response,
                  error: ConflictException(
                    message: msg,
                    conflictingTask: conflicting,
                    proposedTaskData: proposedJson,
                    alternativeFreeSlots: freeSlots,
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Failed to parse 409 conflict detail: $e');
          }
        }

        return handler.next(error);
      },
    ),
  );

  return dio;
});
