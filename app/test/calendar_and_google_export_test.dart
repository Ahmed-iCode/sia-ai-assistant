import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:app/core/models/task_model.dart';
import 'package:app/core/models/user_model.dart';
import 'package:app/core/services/api_client.dart';
import 'package:app/core/services/mock_task_repository.dart';
import 'package:app/core/services/storage_service.dart';
import 'package:app/core/utils/google_calendar_helper.dart';
import 'package:app/core/l10n/locale_provider.dart';
import 'package:app/features/auth/auth_provider.dart';
import 'package:app/features/tasks/tasks_provider.dart';
import 'package:app/features/tasks/widgets/task_calendar_view.dart';
import 'package:app/main.dart';

class _DummyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  Future<AuthState> build() async => _initial;
}

class _FakeLocaleNotifier extends LocaleNotifier {
  final Locale _initial;
  _FakeLocaleNotifier(this._initial);

  @override
  Locale build() => _initial;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.clear();
  });

  group('GoogleCalendarHelper Tests', () {
    test('buildGoogleCalendarUrl formats UTC dates, priority, tags, and timezone correctly', () {
      final startTime = DateTime.utc(2026, 11, 25, 10, 30, 0);
      final endTime = DateTime.utc(2026, 11, 25, 12, 0, 0);

      final task = TaskModel(
        id: 't-gcal-1',
        title: 'Q4 Strategy & AI Roadmap Review',
        description: 'Prepare presentation and review capacity metrics.',
        startTime: startTime,
        endTime: endTime,
        priority: TaskPriority.urgent,
        isVoiceCreated: true,
        tags: ['Strategy', 'AI'],
        createdAt: startTime,
        updatedAt: startTime,
      );

      final uri = GoogleCalendarHelper.buildGoogleCalendarUrl(task, timezone: 'Africa/Cairo');

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('calendar.google.com'));
      expect(uri.path, equals('/calendar/render'));

      final params = uri.queryParameters;
      expect(params['action'], equals('TEMPLATE'));
      expect(params['text'], equals('Q4 Strategy & AI Roadmap Review'));
      expect(params['dates'], equals('20261125T103000Z/20261125T120000Z'));
      expect(params['ctz'], equals('Africa/Cairo'));
      expect(params['details'], contains('Prepare presentation'));
      expect(params['details'], contains('Priority: URGENT'));
      expect(params['details'], contains('Tags: #Strategy #AI'));
      expect(params['details'], contains('Created with AI Task Assistant (Voice)'));
    });

    test('formatGoogleDateTime produces 16-character ISO-basic UTC string', () {
      final dt = DateTime.utc(2026, 1, 5, 9, 5, 0);
      final formatted = GoogleCalendarHelper.formatGoogleDateTime(dt);
      expect(formatted, equals('20260105T090500Z'));
    });
  });

  group('TaskCalendarView Widget Tests', () {
    late Dio fakeDio;
    final fakeUser = UserModel(
      id: 'test-user',
      name: 'Ahmed',
      email: 'ahmed@smarttask.ai',
    );

    setUp(() {
      fakeDio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))..httpClientAdapter = _DummyAdapter();
    });

    testWidgets('renders TableCalendar in Arabic locale with Cairo font & format button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeDio),
            localeProvider.overrideWith(() => _FakeLocaleNotifier(const Locale('ar'))),
            authProvider.overrideWith(
              () => _FakeAuthNotifier(AuthState(
                status: AuthStatus.authenticated,
                user: fakeUser,
              )),
            ),
            taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
          ],
          child: const AiTaskAssistantApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Calendar View
      final calTab = find.text('التقويم');
      expect(calTab, findsOneWidget);
      await tester.tap(calTab);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TaskCalendarView), findsOneWidget);
      expect(find.byType(TableCalendar<TaskModel>), findsOneWidget);
      expect(find.text('إضافة مهمة في هذا اليوم'), findsWidgets);
    });

    testWidgets('renders TableCalendar in English locale cleanly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeDio),
            localeProvider.overrideWith(() => _FakeLocaleNotifier(const Locale('en'))),
            authProvider.overrideWith(
              () => _FakeAuthNotifier(AuthState(
                status: AuthStatus.authenticated,
                user: fakeUser,
              )),
            ),
            taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
          ],
          child: const AiTaskAssistantApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Calendar View
      final calTab = find.text('Calendar');
      expect(calTab, findsOneWidget);
      await tester.tap(calTab);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TableCalendar<TaskModel>), findsOneWidget);
      expect(find.text('Add task on this day'), findsWidgets);
    });
  });
}
