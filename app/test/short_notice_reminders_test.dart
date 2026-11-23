import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/task_model.dart';
import 'package:app/core/models/reminder_model.dart';
import 'package:app/core/services/notification_service.dart';

void main() {
  group('NotificationService calculateTriggerUtc Tests', () {
    final fixedNowUtc = DateTime.utc(2026, 11, 23, 12, 0, 0);

    test('Standard advance reminder (45m before) when trigger is in future', () {
      final task = TaskModel(
        id: 'task-1',
        title: 'Future Meeting',
        startTime: DateTime.utc(2026, 11, 23, 14, 0, 0), // 2 hours in future
        endTime: DateTime.utc(2026, 11, 23, 15, 0, 0),
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
        reminders: [
          ReminderModel(
            id: 'rem-1',
            taskId: 'task-1',
            remindAt: DateTime.utc(2026, 11, 23, 13, 15, 0),
            offsetMinutes: 45,
            isTriggered: false,
          ),
        ],
      );

      final triggerUtc = NotificationService.calculateTriggerUtc(task, fixedNowUtc);
      expect(triggerUtc, isNotNull);
      expect(triggerUtc, DateTime.utc(2026, 11, 23, 13, 15, 0));
    });

    test('Short-notice task (1m in future, 15m default offset): clamps to start time', () {
      // startTime is 1 min from now: 12:01:00
      // 15m before start would be 11:46:00 (in the past!)
      // Should be clamped to startTime (12:01:00)
      final task = TaskModel(
        id: 'task-short-1',
        title: 'Drink Water in 1 Minute',
        startTime: DateTime.utc(2026, 11, 23, 12, 1, 0),
        endTime: DateTime.utc(2026, 11, 23, 12, 31, 0),
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
        reminders: [
          ReminderModel(
            id: 'rem-short',
            taskId: 'task-short-1',
            remindAt: DateTime.utc(2026, 11, 23, 11, 46, 0),
            offsetMinutes: 15,
            isTriggered: false,
          ),
        ],
      );

      final triggerUtc = NotificationService.calculateTriggerUtc(task, fixedNowUtc);
      expect(triggerUtc, isNotNull);
      // Must not be null or in the past
      expect(triggerUtc!.isAfter(fixedNowUtc), isTrue);
      // Trigger should match task start time
      expect(triggerUtc, DateTime.utc(2026, 11, 23, 12, 1, 0));
    });

    test('Zero-offset reminder (offsetMinutes = 0): triggers at start time', () {
      final task = TaskModel(
        id: 'task-zero-1',
        title: 'Instant Reminder',
        startTime: DateTime.utc(2026, 11, 23, 12, 5, 0),
        endTime: DateTime.utc(2026, 11, 23, 12, 35, 0),
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
        reminders: [
          ReminderModel(
            id: 'rem-zero',
            taskId: 'task-zero-1',
            remindAt: DateTime.utc(2026, 11, 23, 12, 5, 0),
            offsetMinutes: 0,
            isTriggered: false,
          ),
        ],
      );

      final triggerUtc = NotificationService.calculateTriggerUtc(task, fixedNowUtc);
      expect(triggerUtc, isNotNull);
      expect(triggerUtc, DateTime.utc(2026, 11, 23, 12, 5, 0));
    });

    test('Very short task (1 second in future): clamps to at least now + 2 seconds', () {
      final task = TaskModel(
        id: 'task-1s',
        title: 'One Second Task',
        startTime: fixedNowUtc.add(const Duration(seconds: 1)),
        endTime: fixedNowUtc.add(const Duration(minutes: 30)),
        status: TaskStatus.pending,
        priority: TaskPriority.low,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
      );

      final triggerUtc = NotificationService.calculateTriggerUtc(task, fixedNowUtc);
      expect(triggerUtc, isNotNull);
      expect(triggerUtc, fixedNowUtc.add(const Duration(seconds: 2)));
    });

    test('Past task: returns null (cancelled/dropped)', () {
      final task = TaskModel(
        id: 'task-past',
        title: 'Yesterday Task',
        startTime: DateTime.utc(2026, 11, 22, 10, 0, 0),
        endTime: DateTime.utc(2026, 11, 22, 11, 0, 0),
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
        reminders: [
          ReminderModel(
            id: 'rem-past',
            taskId: 'task-past',
            remindAt: DateTime.utc(2026, 11, 22, 9, 30, 0),
            offsetMinutes: 30,
            isTriggered: true,
          ),
        ],
      );

      final triggerUtc = NotificationService.calculateTriggerUtc(task, fixedNowUtc);
      expect(triggerUtc, isNull);
    });

    test('Completed or Cancelled task: returns null', () {
      final completedTask = TaskModel(
        id: 'task-completed',
        title: 'Done Task',
        startTime: DateTime.utc(2026, 11, 23, 13, 0, 0),
        endTime: DateTime.utc(2026, 11, 23, 14, 0, 0),
        status: TaskStatus.completed,
        priority: TaskPriority.medium,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
      );
      expect(NotificationService.calculateTriggerUtc(completedTask, fixedNowUtc), isNull);

      final cancelledTask = TaskModel(
        id: 'task-cancelled',
        title: 'Cancelled Task',
        startTime: DateTime.utc(2026, 11, 23, 13, 0, 0),
        endTime: DateTime.utc(2026, 11, 23, 14, 0, 0),
        status: TaskStatus.cancelled,
        priority: TaskPriority.medium,
        createdAt: fixedNowUtc,
        updatedAt: fixedNowUtc,
      );
      expect(NotificationService.calculateTriggerUtc(cancelledTask, fixedNowUtc), isNull);
    });
  });
}
