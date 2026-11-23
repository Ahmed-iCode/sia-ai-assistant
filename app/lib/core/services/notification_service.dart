import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../models/task_model.dart';
import 'app_update_service.dart';
import 'rest_task_repository.dart';

class NotificationService {
  static final NotificationService instance = NotificationService();

  static const String channelId = 'sia_task_reminders';
  static const String channelName = 'تذكيرات Sia | Sia Task Reminders';
  static const String channelDescription = 'تنبيهات وتذكيرات Sia للمهام المجدولة قبل موعدها';

  static const String updateChannelId = 'sia_app_updates';
  static const String updateChannelName = 'تحديثات Sia | Sia Updates';
  static const String updateChannelDescription = 'إشعارات التحديثات والإصدارات الجديدة لتطبيق Sia';
  static const int updateNotificationId = 999001;

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;
  Timer? _webReminderPoller;
  bool allowInTests;

  NotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    this.allowInTests = false,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  bool get _isTestOrWeb {
    if (kIsWeb) return true;
    if (allowInTests) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    } catch (_) {}
    return false;
  }

  /// Pure computation for reminder trigger time with smart clamping.
  /// If reminderUtc is in the future, it is used.
  /// If reminderUtc is in the past but startUtc is in the future (short-notice reminder),
  /// the trigger is clamped to startUtc (or at least 2 seconds ahead of nowUtc).
  /// If both are in the past, returns null.
  static DateTime? calculateTriggerUtc(TaskModel task, [DateTime? referenceNowUtc]) {
    if (task.isCompleted || task.isCancelled) return null;
    final nowUtc = referenceNowUtc ?? DateTime.now().toUtc();
    final startUtc = task.startTime.toUtc();
    final reminderMinutes = task.reminders.isNotEmpty
        ? task.reminders.first.offsetMinutes
        : 15;
    final reminderUtc = startUtc.subtract(Duration(minutes: reminderMinutes));

    DateTime triggerUtc;
    if (reminderUtc.isAfter(nowUtc)) {
      triggerUtc = reminderUtc;
    } else if (startUtc.isAfter(nowUtc)) {
      // Clamped to task start time for short-notice reminders
      triggerUtc = startUtc;
    } else {
      // Both reminder and task start are in the past
      return null;
    }

    // Ensure triggerUtc is at least 2 seconds ahead of nowUtc
    final minTriggerUtc = nowUtc.add(const Duration(seconds: 2));
    if (triggerUtc.isBefore(minTriggerUtc)) {
      triggerUtc = minTriggerUtc;
    }
    return triggerUtc;
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

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null &&
              (payload.startsWith('http://') || payload.startsWith('https://'))) {
            try {
              launchUrl(Uri.parse(payload), mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint('[NotificationService] Error launching notification URL: $e');
            }
          }
        },
      );

      // Create high-priority notification channels on Android
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

        const updateChannel = AndroidNotificationChannel(
          updateChannelId,
          updateChannelName,
          description: updateChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await androidPlatform.createNotificationChannel(updateChannel);

        // Check and request exact alarms permission if not yet permitted on Android 12+
        try {
          final canExact =
              await androidPlatform.canScheduleExactNotifications() ?? false;
          if (!canExact) {
            await androidPlatform.requestExactAlarmsPermission();
          }
        } catch (e) {
          debugPrint('Exact alarms init check/request: $e');
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  /// Checks whether exact alarms permission is granted on Android.
  /// Returns true on non-Android, web, or test environments.
  Future<bool> canScheduleExactAlarms() async {
    if (_isTestOrWeb) return true;
    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        return await androidPlatform.canScheduleExactNotifications() ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking exact alarms permission: $e');
    }
    return true;
  }

  /// Requests exact alarms permission on Android (opens system settings screen).
  Future<bool> requestExactAlarmsPermission() async {
    if (_isTestOrWeb) return true;
    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final res = await androidPlatform.requestExactAlarmsPermission();
        return res ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error requesting exact alarms permission: $e');
    }
    return false;
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

    final triggerUtc = calculateTriggerUtc(task);
    if (triggerUtc == null) {
      // Past reminder & task time, cancel existing reminder if any
      await cancelTaskReminder(task.id);
      return;
    }

    await initialize();

    final reminderMinutes = task.reminders.isNotEmpty
        ? task.reminders.first.offsetMinutes
        : 15;
    final nowUtc = DateTime.now().toUtc();
    final reminderUtc =
        task.startTime.toUtc().subtract(Duration(minutes: reminderMinutes));
    final isClamped =
        !reminderUtc.isAfter(nowUtc) && task.startTime.toUtc().isAfter(nowUtc);

    final notificationId = task.id.hashCode & 0x7FFFFFFF;
    final tzReminder = tz.TZDateTime.from(triggerUtc, tz.UTC);

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
    final body = (reminderMinutes > 0 && !isClamped)
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
    } catch (e) {
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
    final windowCutoff = nowUtc.add(const Duration(days: 14));

    // Filter and sort active upcoming tasks within next 14 days using smart trigger clamping
    final upcomingTasks = tasks
        .where((t) => !t.isCompleted && !t.isCancelled)
        .where((t) {
          final trigger = calculateTriggerUtc(t, nowUtc);
          return trigger != null && t.startTime.toUtc().isBefore(windowCutoff);
        })
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Cap at 40 alarms max to safeguard Android AlarmManager limits
    final toSchedule = upcomingTasks.take(40).toList();
    final toScheduleIds = toSchedule.map((t) => t.id).toSet();

    // Cancel reminders for completed, cancelled, or out-of-window tasks
    for (final task in tasks) {
      if (!toScheduleIds.contains(task.id)) {
        await cancelTaskReminder(task.id);
      }
    }

    // Schedule valid within-window tasks
    for (final task in toSchedule) {
      await scheduleTaskReminder(task);
    }
  }

  /// Get total count of pending scheduled notification requests.
  Future<int> getPendingNotificationCount() async {
    if (_isTestOrWeb) return 0;
    try {
      await initialize();
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('Error getting pending notification count: $e');
      return 0;
    }
  }

  /// Alias for backward compatibility
  Future<void> scheduleTaskReminders(List<TaskModel> tasks) async {
    await syncAllTaskReminders(tasks);
  }

  /// Diagnostics: Fire immediate test notification
  Future<bool> showImmediateTestNotification({
    String title = '🔔 إشعار تجريبي فوري | Sia Test',
    String body = 'نظام التنبيهات المحلي في تطبيق Sia يعمل بنجاح!',
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

  /// Displays a high-priority system notification when a new Sia release is available.
  Future<bool> showUpdateAvailableNotification(
    AppUpdateInfo info, {
    bool isArabic = true,
  }) async {
    if (_isTestOrWeb) return false;
    await initialize();

    final title = isArabic
        ? 'تحديث جديد لتطبيق Sia متوفر الآن! (v${info.versionName})'
        : 'New Sia update available! (v${info.versionName})';
    final body = info.releaseNotes.isNotEmpty
        ? info.releaseNotes
        : (isArabic
            ? 'انقر هنا لتنزيل أحدث إصدار وتثبيته.'
            : 'Tap here to download and install the latest version.');

    const androidDetails = AndroidNotificationDetails(
      updateChannelId,
      updateChannelName,
      channelDescription: updateChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notificationsPlugin.show(
        updateNotificationId,
        title,
        body,
        details,
        payload: info.downloadUrl,
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error showing update notification: $e');
      return false;
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
  final service = NotificationService.instance;
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
