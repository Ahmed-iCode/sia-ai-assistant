import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app/core/l10n/app_localizations.dart';
import 'package:app/core/models/ai_action_card_model.dart';
import 'package:app/core/models/chat_message_model.dart';
import 'package:app/core/models/extracted_task_draft_model.dart';
import 'package:app/core/models/task_model.dart';
import 'package:app/features/ai_assistant/widgets/batch_task_preview_card.dart';
import 'package:app/features/ai_assistant/widgets/chat_bubble.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  group('ExtractedTaskDraftModel Unit Tests', () {
    test('fromJson parses UTC ISO-8601 timestamps and camelCase fields', () {
      final json = {
        'id': 'draft-123',
        'title': 'محاضرة فيزياء',
        'description': 'مدرج ب',
        'startTime': '2026-11-23T08:00:00Z',
        'endTime': '2026-11-23T10:00:00Z',
        'priority': 'high',
        'category': 'Study',
        'reminderMinutes': 20,
      };

      final draft = ExtractedTaskDraftModel.fromJson(json);
      expect(draft.id, 'draft-123');
      expect(draft.title, 'محاضرة فيزياء');
      expect(draft.description, 'مدرج ب');
      expect(draft.priority, TaskPriority.high);
      expect(draft.category, 'Study');
      expect(draft.reminderMinutes, 20);
      expect(draft.isSelected, true);
    });

    test('toTaskCreateJson formats payload for backend batch API', () {
      final start = DateTime.utc(2026, 11, 23, 8, 0);
      final end = DateTime.utc(2026, 11, 23, 10, 0);
      final draft = ExtractedTaskDraftModel(
        title: 'Team Sync',
        startTime: start,
        endTime: end,
        priority: TaskPriority.urgent,
        category: 'Work',
      );

      final payload = draft.toTaskCreateJson();
      expect(payload['title'], 'Team Sync');
      expect(payload['priority'], 'urgent');
      expect(payload['status'], 'pending');
      expect(payload['force'], true);
      expect(payload['tags'], ['Work']);
      expect(payload['startTime'], contains('Z'));
      expect(payload['endTime'], contains('Z'));
    });
  });

  group('BatchTaskPreviewCard Widget Tests', () {
    Widget buildCardTestWidget({
      required List<ExtractedTaskDraftModel> tasks,
      bool isExecuted = false,
      Future<void> Function(List<ExtractedTaskDraftModel>)? onConfirm,
    }) {
      return MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: BatchTaskPreviewCard(
              tasks: tasks,
              isExecuted: isExecuted,
              onConfirm: onConfirm,
            ),
          ),
        ),
      );
    }

    testWidgets('renders task draft titles and select count in header', (tester) async {
      final now = DateTime.now();
      final tasks = [
        ExtractedTaskDraftModel(
          id: '1',
          title: 'محاضرة رياضيات',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          priority: TaskPriority.high,
        ),
        ExtractedTaskDraftModel(
          id: '2',
          title: 'معمل كيمياء',
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 4)),
          priority: TaskPriority.medium,
        ),
      ];

      await tester.pumpWidget(buildCardTestWidget(tasks: tasks));
      await tester.pumpAndSettle();

      expect(find.text('محاضرة رياضيات'), findsOneWidget);
      expect(find.text('معمل كيمياء'), findsOneWidget);
      expect(find.text('المواعيد المستخرجة (2)'), findsOneWidget);
      expect(find.text('تأكيد وإضافة (2) مهام'), findsOneWidget);
    });

    testWidgets('toggle checkbox updates selected count on primary button', (tester) async {
      final now = DateTime.now();
      final tasks = [
        ExtractedTaskDraftModel(
          id: '1',
          title: 'مهمة أ',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
        ),
        ExtractedTaskDraftModel(
          id: '2',
          title: 'مهمة ب',
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 3)),
        ),
      ];

      await tester.pumpWidget(buildCardTestWidget(tasks: tasks));
      await tester.pumpAndSettle();

      // Tap on first checkbox to deselect it
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Now 1 selected
      expect(find.text('تأكيد وإضافة (1) مهام'), findsOneWidget);
    });

    testWidgets('calls onConfirm with selected tasks on tap', (tester) async {
      final now = DateTime.now();
      final tasks = [
        ExtractedTaskDraftModel(
          id: '1',
          title: 'اجتماع عمل',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
        ),
      ];

      List<ExtractedTaskDraftModel>? confirmedTasks;
      await tester.pumpWidget(buildCardTestWidget(
        tasks: tasks,
        onConfirm: (selected) async {
          confirmedTasks = selected;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تأكيد وإضافة (1) مهام'));
      await tester.pumpAndSettle();

      expect(confirmedTasks, isNotNull);
      expect(confirmedTasks!.length, 1);
      expect(confirmedTasks!.first.title, 'اجتماع عمل');
    });

    testWidgets('displays success banner when isExecuted is true', (tester) async {
      final now = DateTime.now();
      final tasks = [
        ExtractedTaskDraftModel(
          id: '1',
          title: 'كشف طبي',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
        ),
      ];

      await tester.pumpWidget(buildCardTestWidget(tasks: tasks, isExecuted: true));
      await tester.pumpAndSettle();

      expect(find.text('تمت إضافة المهام بنجاح ✓'), findsOneWidget);
      expect(find.text('تأكيد وإضافة (1) مهام'), findsNothing);
    });
  });

  group('ChatBubble Attachment and Batch Card Integration Tests', () {
    Widget buildBubbleTestWidget(ChatMessageModel message) {
      return MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatBubble(
              message: message,
              onUndoTask: () {},
              onConfirmDelete: () {},
              onCancelDelete: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders attachment pill for file message', (tester) async {
      final message = ChatMessageModel(
        id: 'msg-attach',
        sender: MessageSender.user,
        text: 'استخرج جدول الامتحانات',
        timestamp: DateTime.now(),
        attachmentName: 'exam_schedule.pdf',
        attachmentSizeBytes: 1024 * 150,
      );

      await tester.pumpWidget(buildBubbleTestWidget(message));
      await tester.pumpAndSettle();

      expect(find.text('exam_schedule.pdf'), findsOneWidget);
      expect(find.text('استخرج جدول الامتحانات'), findsOneWidget);
    });

    testWidgets('renders BatchTaskPreviewCard inside assistant message with batchTasksPreview', (tester) async {
      final now = DateTime.now();
      final message = ChatMessageModel(
        id: 'msg-batch',
        sender: MessageSender.assistant,
        text: 'تم استخراج 2 مواعيد من الملف بنجاح:',
        timestamp: DateTime.now(),
        actionCard: AiActionCardModel(
          type: AiCardType.batchTasksPreview,
          extractedTasks: [
            ExtractedTaskDraftModel(
              id: '1',
              title: 'امتحان فيزياء',
              startTime: now,
              endTime: now.add(const Duration(hours: 2)),
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildBubbleTestWidget(message));
      await tester.pumpAndSettle();

      expect(find.byType(BatchTaskPreviewCard), findsOneWidget);
      expect(find.text('امتحان فيزياء'), findsOneWidget);
    });
  });
}
