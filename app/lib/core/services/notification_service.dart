import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';
import 'rest_task_repository.dart';

class NotificationService {
  static const String channelId = 'sia_task_reminders';
  static const String channelName = 'تذكيرات المهام | Task Reminders';
  static const String channelDescription = 'تنبيهات وتذكيرات المهام المجدولة قبل موعدها';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Timer? _webReminderPoller;

  bool get _isTestOrWeb {
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    } catch (_) {}
    return false;
  }

  Future<void> initialize({String timezoneName = 'Africa/Cairo'}) async {
    if (_isInitialized) return;

    if (_isTestOrWeb) {
      _isInitialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(timezoneName));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
        } catch (_) {}
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);

      // Create high-priority notification channel on Android
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidPlatform.createNotificationChannel(channel);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (_isTestOrWeb) return false;
    await initialize();

    try {
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final notifGranted =
            await androidPlatform.requestNotificationsPermission() ?? false;

        // Android 12+ (API 31+) exact alarms permission check & request
        try {
          final canExact =
              await androidPlatform.canScheduleExactNotifications() ?? false;
          if (!canExact) {
            await androidPlatform.requestExactAlarmsPermission();
          }
        } catch (e) {
          debugPrint('Exact alarms check/request info: $e');
        }
        return notifGranted;
      }

      final iosPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        final granted = await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  Future<void> scheduleTaskReminder(TaskModel task) async {
    if (_isTestOrWeb) return;
    if (task.isCompleted || task.isCancelled) {
      await cancelTaskReminder(task.id);
      return;
    }

    await initialize();

    final reminderMinutes = task.reminders.isNotEmpty
        ? task.reminders.first.offsetMinutes
        : 30;

    final reminderUtc =
        task.startTime.toUtc().subtract(Duration(minutes: reminderMinutes));
    final nowUtc = DateTime.now().toUtc();

    if (!reminderUtc.isAfter(nowUtc)) {
      // Past reminder time, do not schedule
      return;
    }

    final notificationId = task.id.hashCode & 0x7FFFFFFF;
    final tzReminder = tz.TZDateTime.from(reminderUtc, tz.UTC);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final title = '⏰ تذكير بمهمة: ${task.title}';
    final body = reminderMinutes > 0
        ? 'تبدأ المهمة خلال $reminderMinutes دقيقة'
        : 'موعد بدء المهمة الآن';

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tzReminder,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    } on PlatformException catch (e) {
      debugPrint(
          'Exact alarm failed ($e), falling back to inexactAllowWhileIdle');
      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          tzReminder,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      } catch (err) {
        debugPrint('Fallback inexact alarm also failed: $err');
      }
    } catch (e) {
      debugPrint('General error scheduling reminder: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          tzReminder,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (_isTestOrWeb) return;
    try {
      await initialize();
      final notificationId = taskId.hashCode & 0x7FFFFFFF;
      await _notificationsPlugin.cancel(notificationId);
    } catch (e) {
      debugPrint('Error cancelling task reminder $taskId: $e');
    }
  }

  Future<void> syncAllTaskReminders(List<TaskModel> tasks) async {
    if (_isTestOrWeb) return;
    await initialize();

    final nowUtc = DateTime.now().toUtc();
    for (final task in tasks) {
      if (task.isCompleted || task.isCancelled) {
        await cancelTaskReminder(task.id);
      } else {
        final reminderMinutes = task.reminders.isNotEmpty
            ? task.reminders.first.offsetMinutes
            : 30;
        final reminderUtc =
            task.startTime.toUtc().subtract(Duration(minutes: reminderMinutes));
        if (reminderUtc.isAfter(nowUtc)) {
          await scheduleTaskReminder(task);
        } else {
          await cancelTaskReminder(task.id);
        }
      }
    }
  }

  /// Alias for backward compatibility
  Future<void> scheduleTaskReminders(List<TaskModel> tasks) async {
    await syncAllTaskReminders(tasks);
  }

  /// Diagnostics: Fire immediate test notification
  Future<bool> showImmediateTestNotification({
    String title = '🔔 إشعار تجريبي فوري | Sia Test',
    String body = 'نظام التنبيهات المحلي في تطبيق سيا يعمل بنجاح!',
  }) async {
    if (_isTestOrWeb) return false;
    await initialize();
    await requestPermissions();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    const testId = 999999;
    try {
      await _notificationsPlugin.show(testId, title, body, details);
      return true;
    } catch (e) {
      debugPrint('Error showing immediate test notification: $e');
      return false;
    }
  }

  /// Diagnostics: Schedule a test notification 10 seconds from now
  Future<bool> scheduleDelayed10sTestNotification({
    String title = '⏰ تذكير تجريبي بعد 10 ثواني | Sia Test',
    String body = 'نجح اختبار التنبيه المجدول بينما التطبيق مغلق أو في الخلفية!',
  }) async {
    if (_isTestOrWeb) return false;
    await initialize();
    await requestPermissions();

    final triggerUtc = DateTime.now().toUtc().add(const Duration(seconds: 10));
    final tzTrigger = tz.TZDateTime.from(triggerUtc, tz.UTC);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    const testId = 999998;
    try {
      await _notificationsPlugin.zonedSchedule(
        testId,
        title,
        body,
        tzTrigger,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (e) {
      debugPrint('Exact 10s test alarm failed, fallback to inexact: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          testId,
          title,
          body,
          tzTrigger,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return true;
      } catch (err) {
        debugPrint('Fallback 10s test alarm failed: $err');
        return false;
      }
    }
  }

  void startWebPolling(
      RestTaskRepository repo, void Function(String title) onTrigger) {
    if (!kIsWeb) return;
    _webReminderPoller?.cancel();
    _webReminderPoller =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
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
