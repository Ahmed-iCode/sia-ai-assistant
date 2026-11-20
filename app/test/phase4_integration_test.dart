import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/models/user_model.dart';
import 'package:app/core/models/user_settings_model.dart';
import 'package:app/core/models/task_model.dart';
import 'package:app/core/models/ai_action_card_model.dart';
import 'package:app/core/models/free_slot_model.dart';
import 'package:app/core/services/api_config.dart';
import 'package:app/core/services/storage_service.dart';
import 'package:app/core/services/rest_task_repository.dart';
import 'package:app/core/services/auth_service.dart';

class MockAdapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.clear();
  });

  group('StorageService Tests', () {
    test('safe get, set and remove works', () async {
      expect(await StorageService.getString('key1'), isNull);
      await StorageService.setString('key1', 'value1');
      expect(await StorageService.getString('key1'), equals('value1'));
      await StorageService.remove('key1');
      expect(await StorageService.getString('key1'), isNull);
    });
  });

  group('ApiConfig Tests', () {
    test('default URL is 127.0.0.1:8000/api/v1', () {
      final config = ApiConfigNotifier();
      expect(config.state, contains('8000/api/v1'));
    });

    test('can update base URL and persist', () async {
      final config = ApiConfigNotifier();
      await config.setBaseUrl('http://192.168.1.100:8000/api/v1');
      expect(config.state, equals('http://192.168.1.100:8000/api/v1'));

      final saved = await StorageService.getString('api_base_url_override');
      expect(saved, equals('http://192.168.1.100:8000/api/v1'));

      await config.resetToDefault();
      expect(config.state, equals(ApiConfigNotifier.defaultBaseUrl));
    });
  });

  group('Model Serialization Tests', () {
    test('UserModel roundtrip serialization', () {
      final user = UserModel(
        id: 'usr-123',
        name: 'Ahmed',
        email: 'ahmed@example.com',
        settings: const UserSettingsModel(
          language: 'ar',
          themeMode: 'dark',
          workingHoursStart: '09:00',
          workingHoursEnd: '21:00',
        ),
      );

      final json = user.toJson();
      expect(json['id'], equals('usr-123'));
      expect(json['email'], equals('ahmed@example.com'));
      expect(json['settings']['workingHoursStart'], equals('09:00'));

      final parsed = UserModel.fromJson(json);
      expect(parsed.id, equals(user.id));
      expect(parsed.settings.workingHoursEnd, equals('21:00'));
    });

    test('AiActionCardModel roundtrip serialization', () {
      final now = DateTime.now();
      final card = AiActionCardModel(
        type: AiCardType.conflictAlert,
        task: TaskModel(
          id: 't-1',
          title: 'Proposed',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          createdAt: now,
          updatedAt: now,
        ),
        freeSlots: [
          FreeSlotModel(
            start: now.add(const Duration(hours: 2)),
            end: now.add(const Duration(hours: 3)),
            durationMinutes: 60,
          ),
        ],
        message: 'Conflict alert message',
      );

      final json = card.toJson();
      expect(json['type'], equals('conflictAlert'));
      expect(json['task']['title'], equals('Proposed'));
      expect(json['freeSlots'], hasLength(1));

      final parsed = AiActionCardModel.fromJson(json);
      expect(parsed.type, equals(AiCardType.conflictAlert));
      expect(parsed.freeSlots.first.durationMinutes, equals(60));
    });

    test('TaskModel safely converts naive and UTC strings to local device time', () {
      // 1. Explicit UTC with Z
      final taskWithZ = TaskModel.fromJson({
        'id': 'tz-1',
        'title': 'UTC Task',
        'startTime': '2026-11-20T11:00:00Z',
        'endTime': '2026-11-20T12:00:00Z',
        'priority': 'medium',
        'status': 'pending',
        'createdAt': '2026-11-20T09:00:00Z',
        'updatedAt': '2026-11-20T09:00:00Z',
      });
      expect(taskWithZ.startTime.isUtc, isFalse); // Converted to local
      expect(taskWithZ.toJson()['startTime'], endsWith('Z')); // Serialized back to UTC

      // 2. Naive string without Z (assumed UTC from database)
      final taskNaive = TaskModel.fromJson({
        'id': 'tz-2',
        'title': 'Naive Task',
        'startTime': '2026-11-20T11:00:00',
        'endTime': '2026-11-20T12:00:00',
        'priority': 'medium',
        'status': 'pending',
        'createdAt': '2026-11-20T09:00:00',
        'updatedAt': '2026-11-20T09:00:00',
      });
      expect(taskNaive.startTime.isUtc, isFalse);
      expect(taskNaive.startTime, equals(taskWithZ.startTime));
    });
  });

  group('RestTaskRepository Live Integration Simulation', () {
    late Dio dio;
    late MockAdapter adapter;
    late RestTaskRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      adapter = MockAdapter();
      dio.httpClientAdapter = adapter;
      repo = RestTaskRepository(dio);
    });

    test('getTasks parses list of tasks correctly', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '''[
            {
              "id": "t-1",
              "title": "Team Meeting",
              "startTime": "2026-11-25T10:00:00.000Z",
              "endTime": "2026-11-25T11:00:00.000Z",
              "priority": "high",
              "status": "pending",
              "isVoiceCreated": false,
              "tags": [],
              "reminders": [],
              "createdAt": "2026-11-25T08:00:00.000Z",
              "updatedAt": "2026-11-25T08:00:00.000Z"
            }
          ]''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final tasks = await repo.getTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.title, equals('Team Meeting'));
      expect(tasks.first.priority, equals(TaskPriority.high));
    });

    test('createTask parses created task response', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '''{
            "id": "created-101",
            "title": "Client Review",
            "startTime": "2026-11-25T14:00:00.000Z",
            "endTime": "2026-11-25T15:00:00.000Z",
            "priority": "urgent",
            "status": "pending",
            "isVoiceCreated": true,
            "tags": [],
            "reminders": [],
            "createdAt": "2026-11-25T08:00:00.000Z",
            "updatedAt": "2026-11-25T08:00:00.000Z"
          }''',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final now = DateTime.now();
      final task = TaskModel(
        id: '',
        title: 'Client Review',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        priority: TaskPriority.urgent,
        createdAt: now,
        updatedAt: now,
      );

      final created = await repo.createTask(task);
      expect(created.id, equals('created-101'));
      expect(created.isVoiceCreated, isTrue);
    });

    test('actions/confirm-delete posts successfully', () async {
      adapter.handler = (options) {
        expect(options.path, equals('/assistant/actions/confirm-delete/t-del'));
        return ResponseBody.fromString(
          '{"success": true, "deletedTaskId": "t-del", "tasksMutated": true}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      await repo.confirmDeleteAction('t-del');
    });

    test('actions/undo-create posts successfully', () async {
      adapter.handler = (options) {
        expect(options.path, equals('/assistant/actions/undo-create/t-undo'));
        return ResponseBody.fromString(
          '{"success": true, "message": "undone", "tasksMutated": true}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      await repo.undoCreateAction('t-undo');
    });
  });

  group('AuthService Tests', () {
    late Dio dio;
    late MockAdapter adapter;
    late AuthService auth;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      adapter = MockAdapter();
      dio.httpClientAdapter = adapter;
      auth = AuthService(dio);
    });

    test('login saves token and returns user profile', () async {
      adapter.handler = (options) {
        if (options.path == '/auth/login') {
          return ResponseBody.fromString(
            '{"accessToken": "fake_jwt_token_123", "tokenType": "bearer"}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else if (options.path == '/auth/me') {
          return ResponseBody.fromString(
            '''{
              "id": "u-1",
              "name": "Ahmed Live",
              "email": "ahmed@live.ai",
              "isActive": true,
              "settings": {
                "language": "ar",
                "themeMode": "dark"
              }
            }''',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      };

      final user = await auth.login(email: 'ahmed@live.ai', password: 'password');
      expect(user.email, equals('ahmed@live.ai'));

      final token = await auth.getSavedToken();
      expect(token, equals('fake_jwt_token_123'));

      await auth.logout();
      expect(await auth.getSavedToken(), isNull);
    });
  });
}
