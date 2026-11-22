import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:app/core/l10n/app_localizations.dart';
import 'package:app/core/models/task_model.dart';
import 'package:app/features/tasks/widgets/task_card.dart';
import 'package:app/features/tasks/widgets/task_form_sheet.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  group('TaskModel Recurrence Unit Tests', () {
    test('fromJson parses recurrence fields from API JSON response', () {
      final json = {
        'id': 'task-rec-1',
        'title': 'Daily Morning Standup',
        'startTime': '2026-11-23T09:00:00Z',
        'endTime': '2026-11-23T09:30:00Z',
        'priority': 'medium',
        'status': 'pending',
        'recurrence_type': 'daily',
        'recurrence_days': ['mon', 'tue', 'wed', 'thu'],
        'recurrence_group_id': 'grp-uuid-123',
        'recurrence_count': 20,
        'recurrence_end_date': '2026-12-23T09:00:00Z',
        'is_recurrence_active': true,
        'created_at': '2026-11-22T12:00:00Z',
        'updated_at': '2026-11-22T12:00:00Z',
      };

      final task = TaskModel.fromJson(json);
      expect(task.id, 'task-rec-1');
      expect(task.title, 'Daily Morning Standup');
      expect(task.recurrenceType, 'daily');
      expect(task.isRecurring, true);
      expect(task.recurrenceDays, ['mon', 'tue', 'wed', 'thu']);
      expect(task.recurrenceGroupId, 'grp-uuid-123');
      expect(task.recurrenceCount, 20);
      expect(task.isRecurrenceActive, true);
      expect(task.recurrenceEndDate, isNotNull);
    });

    test('fromJson handles comma-separated recurrenceDays string safely', () {
      final json = {
        'id': 'task-rec-2',
        'title': 'Weekly Gym',
        'startTime': '2026-11-23T18:00:00Z',
        'endTime': '2026-11-23T19:30:00Z',
        'priority': 'high',
        'status': 'pending',
        'recurrenceType': 'weekly',
        'recurrenceDays': 'sun,tue,thu',
        'createdAt': '2026-11-22T12:00:00Z',
        'updatedAt': '2026-11-22T12:00:00Z',
      };

      final task = TaskModel.fromJson(json);
      expect(task.isRecurring, true);
      expect(task.recurrenceType, 'weekly');
      expect(task.recurrenceDays, ['sun', 'tue', 'thu']);
    });

    test('isRecurring returns false for non-recurring task', () {
      final task = TaskModel(
        id: 'task-1',
        title: 'Single Task',
        startTime: DateTime.utc(2026, 11, 23, 10),
        endTime: DateTime.utc(2026, 11, 23, 11),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.recurrenceType, 'none');
      expect(task.isRecurring, false);
    });

    test('toJson serializes recurrence fields in snake_case for backend', () {
      final task = TaskModel(
        id: 'task-3',
        title: 'Monthly Review',
        startTime: DateTime.utc(2026, 11, 23, 10),
        endTime: DateTime.utc(2026, 11, 23, 11),
        recurrenceType: 'monthly',
        recurrenceCount: 12,
        recurrenceGroupId: 'grp-month-456',
        isRecurrenceActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = task.toJson();
      expect(json['recurrence_type'], 'monthly');
      expect(json['recurrence_count'], 12);
      expect(json['recurrence_group_id'], 'grp-month-456');
      expect(json['is_recurrence_active'], true);
    });
  });

  group('TaskCard Recurrence Widget Tests', () {
    Widget buildTestCard(TaskModel task, {Locale locale = const Locale('ar')}) {
      return ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          home: Scaffold(
            body: TaskCard(
              task: task,
              onToggleComplete: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('Renders repeat badge when task is recurring (Arabic)', (tester) async {
      final recurringTask = TaskModel(
        id: 'task-rec',
        title: 'تمرين الجيم',
        startTime: DateTime.utc(2026, 11, 23, 17, 0),
        endTime: DateTime.utc(2026, 11, 23, 18, 30),
        recurrenceType: 'daily',
        recurrenceGroupId: 'grp-1',
        isRecurrenceActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestCard(recurringTask, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Repeat icon and Arabic label 'يومياً' should be visible
      expect(find.byIcon(LucideIcons.repeat), findsOneWidget);
      expect(find.text('يومياً'), findsOneWidget);
    });

    testWidgets('Renders repeat badge when task is weekly (English)', (tester) async {
      final recurringTask = TaskModel(
        id: 'task-rec-en',
        title: 'Weekly Standup',
        startTime: DateTime.utc(2026, 11, 23, 9, 0),
        endTime: DateTime.utc(2026, 11, 23, 9, 30),
        recurrenceType: 'weekly',
        recurrenceGroupId: 'grp-2',
        isRecurrenceActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestCard(recurringTask, locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.repeat), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
    });

    testWidgets('Does NOT render repeat badge for non-recurring task', (tester) async {
      final normalTask = TaskModel(
        id: 'task-normal',
        title: 'One-off meeting',
        startTime: DateTime.utc(2026, 11, 23, 14, 0),
        endTime: DateTime.utc(2026, 11, 23, 15, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestCard(normalTask, locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.repeat), findsNothing);
    });

    testWidgets('Shows Stop Repeating popup menu option for active recurring task', (tester) async {
      final recurringTask = TaskModel(
        id: 'task-rec-menu',
        title: 'Running',
        startTime: DateTime.utc(2026, 11, 23, 6, 0),
        endTime: DateTime.utc(2026, 11, 23, 7, 0),
        recurrenceType: 'daily',
        recurrenceGroupId: 'grp-run-99',
        isRecurrenceActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestCard(recurringTask, locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Tap context menu
      await tester.tap(find.byIcon(LucideIcons.moreVertical));
      await tester.pumpAndSettle();

      // Popup menu item 'Stop Repeating' should appear
      expect(find.text('Stop Repeating'), findsOneWidget);
    });
  });

  group('TaskFormSheet Recurrence UI Widget Tests', () {
    Widget buildTestFormSheet({Locale locale = const Locale('ar')}) {
      return ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          home: const Scaffold(
            body: TaskFormSheet(),
          ),
        ),
      );
    }

    testWidgets('Renders recurrence selector with choices in Arabic', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestFormSheet(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Label and options
      expect(find.text('التكرار'), findsOneWidget);
      expect(find.text('بدون'), findsOneWidget);
      expect(find.text('يومياً'), findsOneWidget);
      expect(find.text('أسبوعياً'), findsOneWidget);
      expect(find.text('شهرياً'), findsOneWidget);

      // Tap 'أسبوعياً'
      await tester.tap(find.text('أسبوعياً'));
      await tester.pumpAndSettle();

      // Weekdays section should now appear
      expect(find.text('أيام التكرار'), findsOneWidget);
      expect(find.text('أحد'), findsOneWidget);
      expect(find.text('سبت'), findsOneWidget);

      // Repeat Ends section should appear
      expect(find.text('نهاية التكرار'), findsOneWidget);
      expect(find.text('مستمر (حتى الإيقاف)'), findsOneWidget);
      expect(find.text('عدد المرات'), findsOneWidget);
      expect(find.text('حتى تاريخ'), findsOneWidget);
    });
  });
}
