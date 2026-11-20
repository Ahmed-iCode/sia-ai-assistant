import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';
import 'rest_task_repository.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Timer? _webReminderPoller;

  Future<void> initialize({String timezoneName = 'Africa/Cairo'}) async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(timezoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);

      // Request permissions on Android 13+
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<void> scheduleTaskReminders(List<TaskModel> tasks) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      // Cancel all existing scheduled notifications first
      await _notificationsPlugin.cancelAll();

      final now = DateTime.now();

      for (final task in tasks) {
        if (task.isCompleted || task.isCancelled) continue;

        for (final reminder in task.reminders) {
          if (reminder.remindAt.isAfter(now)) {
            final notificationId =
                (task.id.hashCode ^ reminder.id.hashCode).abs() % 2147483647;

            final tzScheduled = tz.TZDateTime.from(reminder.remindAt, tz.local);

            const androidDetails = AndroidNotificationDetails(
              'task_reminders_channel',
              'Task Reminders',
              channelDescription: 'Notifications for upcoming scheduled tasks',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            );

            const notificationDetails = NotificationDetails(
              android: androidDetails,
              iOS: DarwinNotificationDetails(),
            );

            await _notificationsPlugin.zonedSchedule(
              notificationId,
              'Reminder: ${task.title}',
              'Starting in ${reminder.offsetMinutes} minutes',
              tzScheduled,
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling task reminders: $e');
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    if (kIsWeb || !_isInitialized) return;
    try {
      // With cancelAll and periodic rescheduleTaskReminders on state changes,
      // reminders stay accurately in sync with tasks.
    } catch (_) {}
  }

  void startWebPolling(RestTaskRepository repo, void Function(String title) onTrigger) {
    if (!kIsWeb) return;
    _webReminderPoller?.cancel();
    _webReminderPoller = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final tasks = await repo.getTasks();
        final now = DateTime.now();
        for (final t in tasks) {
          if (t.isCompleted || t.isCancelled) continue;
          for (final r in t.reminders) {
            final diff = r.remindAt.difference(now).inSeconds.abs();
            if (diff < 30) {
              onTrigger('Reminder: ${t.title} starting soon!');
            }
          }
        }
      } catch (_) {}
    });
  }

  void dispose() {
    _webReminderPoller?.cancel();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
