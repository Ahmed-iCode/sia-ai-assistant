import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:app/core/models/task_model.dart';
import 'package:app/core/models/reminder_model.dart';
import 'package:app/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  group('Exact Alarm Fallback Tests', () {
    final List<MethodCall> methodCalls = [];
    late NotificationService service;

    setUp(() {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tz.initializeTimeZones();

      methodCalls.clear();
      service = NotificationService(allowInTests: true);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);

        switch (methodCall.method) {
          case 'initialize':
            return true;
          case 'canScheduleExactNotifications':
            return false;
          case 'requestExactAlarmsPermission':
            return true;
          case 'requestNotificationsPermission':
            return true;
          case 'createNotificationChannel':
            return null;
          case 'zonedSchedule':
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            final platformSpecifics =
                args['platformSpecifics'] as Map<dynamic, dynamic>?;
            final scheduleMode =
                platformSpecifics?['scheduleMode'] ?? args['scheduleMode'];
            if (scheduleMode == 'exactAllowWhileIdle') {
              throw PlatformException(
                code: 'exact_alarms_not_permitted',
                message: 'Exact alarms not permitted on this Android version',
              );
            }
            // Fallback mode succeeds
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('canScheduleExactAlarms queries platform correctly', () async {
      final canExact = await service.canScheduleExactAlarms();
      expect(canExact, isFalse);
    });

    test('requestExactAlarmsPermission invokes platform channel', () async {
      final requested = await service.requestExactAlarmsPermission();
      expect(requested, isTrue);
      expect(
        methodCalls.any((call) => call.method == 'requestExactAlarmsPermission'),
        isTrue,
      );
    });

    test(
        'scheduleTaskReminder catches exact_alarms_not_permitted and retries with inexactAllowWhileIdle',
        () async {
      final nowUtc = DateTime.now().toUtc();
      final task = TaskModel(
        id: 'task-fallback-1',
        title: 'Standup Meeting',
        startTime: nowUtc.add(const Duration(minutes: 30)),
        endTime: nowUtc.add(const Duration(hours: 1)),
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        createdAt: nowUtc,
        updatedAt: nowUtc,
        reminders: [
          ReminderModel(
            id: 'rem-fallback-1',
            taskId: 'task-fallback-1',
            remindAt: nowUtc.add(const Duration(minutes: 15)),
            offsetMinutes: 15,
            isTriggered: false,
          ),
        ],
      );

      final result = await service.scheduleTaskReminder(task);
      expect(result.success, isTrue);
      expect(result.isInexact, isTrue);

      final zonedCalls =
          methodCalls.where((call) => call.method == 'zonedSchedule').toList();

      // First attempt was exactAllowWhileIdle (threw PlatformException)
      // Second attempt was inexactAllowWhileIdle (succeeded)
      expect(zonedCalls.length, 2);
      final firstArgs = zonedCalls[0].arguments as Map;
      final secondArgs = zonedCalls[1].arguments as Map;
      final firstMode =
          (firstArgs['platformSpecifics'] as Map?)?['scheduleMode'] ??
              firstArgs['scheduleMode'];
      final secondMode =
          (secondArgs['platformSpecifics'] as Map?)?['scheduleMode'] ??
              secondArgs['scheduleMode'];
      expect(firstMode, 'exactAllowWhileIdle');
      expect(secondMode, 'inexactAllowWhileIdle');
    });

    test(
        'scheduleDelayed10sTestNotification falls back to inexact and returns true',
        () async {
      final result = await service.scheduleDelayed10sTestNotification();
      expect(result.success, isTrue);
      expect(result.isInexact, isTrue);

      final zonedCalls =
          methodCalls.where((call) => call.method == 'zonedSchedule').toList();

      expect(zonedCalls.length, 2);
      final firstArgs = zonedCalls[0].arguments as Map;
      final secondArgs = zonedCalls[1].arguments as Map;
      final firstMode =
          (firstArgs['platformSpecifics'] as Map?)?['scheduleMode'] ??
              firstArgs['scheduleMode'];
      final secondMode =
          (secondArgs['platformSpecifics'] as Map?)?['scheduleMode'] ??
              secondArgs['scheduleMode'];
      expect(firstMode, 'exactAllowWhileIdle');
      expect(secondMode, 'inexactAllowWhileIdle');
    });
  });
}
