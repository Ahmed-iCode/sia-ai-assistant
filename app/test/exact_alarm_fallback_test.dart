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
  const MethodChannel settingsChannel =
      MethodChannel('com.taskassistant.app/system_settings');

  group('Exact Alarm Fallback Tests', () {
    final List<MethodCall> methodCalls = [];
    final List<MethodCall> settingsCalls = [];
    late Set<String> blockedScheduleModes;
    late NotificationService service;

    TaskModel buildSampleTask() {
      final nowUtc = DateTime.now().toUtc();
      return TaskModel(
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
    }

    setUp(() {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tz.initializeTimeZones();

      methodCalls.clear();
      settingsCalls.clear();
      blockedScheduleModes = {'alarmClock', 'exactAllowWhileIdle'};
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
            if (blockedScheduleModes.contains(scheduleMode)) {
              throw PlatformException(
                code: 'exact_alarms_not_permitted',
                message: 'Exact alarms not permitted on this Android version',
              );
            }
            // Allowed mode succeeds
            return null;
          default:
            return null;
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(settingsChannel,
              (MethodCall methodCall) async {
        settingsCalls.add(methodCall);
        if (methodCall.method == 'openAppSettings') {
          return true;
        }
        return false;
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(settingsChannel, null);
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

    test('openBackgroundBatterySettings invokes system settings MethodChannel',
        () async {
      final opened = await service.openBackgroundBatterySettings();
      expect(opened, isTrue);
      expect(settingsCalls.length, 1);
      expect(settingsCalls.first.method, 'openAppSettings');
    });

    test(
        'scheduleTaskReminder uses alarmClock as primary schedule mode when allowed',
        () async {
      blockedScheduleModes = {};
      final result = await service.scheduleTaskReminder(buildSampleTask());
      expect(result.success, isTrue);
      expect(result.mode, 'alarmClock');
      expect(result.isAlarmClock, isTrue);
      expect(result.isExact, isTrue);

      final zonedCalls =
          methodCalls.where((call) => call.method == 'zonedSchedule').toList();
      expect(zonedCalls.length, 1);
      final args = zonedCalls[0].arguments as Map;
      final mode =
          (args['platformSpecifics'] as Map?)?['scheduleMode'] ??
              args['scheduleMode'];
      expect(mode, 'alarmClock');
    });

    test(
        'scheduleTaskReminder falls back from alarmClock to exactAllowWhileIdle',
        () async {
      blockedScheduleModes = {'alarmClock'};
      final result = await service.scheduleTaskReminder(buildSampleTask());
      expect(result.success, isTrue);
      expect(result.mode, 'exact');
      expect(result.isAlarmClock, isFalse);
      expect(result.isExact, isTrue);

      final zonedCalls =
          methodCalls.where((call) => call.method == 'zonedSchedule').toList();
      expect(zonedCalls.length, 2);
      final modes = zonedCalls.map((call) {
        final args = call.arguments as Map;
        return (args['platformSpecifics'] as Map?)?['scheduleMode'] ??
            args['scheduleMode'];
      }).toList();
      expect(modes, ['alarmClock', 'exactAllowWhileIdle']);
    });

    test(
        'scheduleTaskReminder falls back through alarmClock -> exactAllowWhileIdle -> inexactAllowWhileIdle',
        () async {
      final result = await service.scheduleTaskReminder(buildSampleTask());
      expect(result.success, isTrue);
      expect(result.mode, 'inexact');
      expect(result.isInexact, isTrue);

      final zonedCalls =
          methodCalls.where((call) => call.method == 'zonedSchedule').toList();

      expect(zonedCalls.length, 3);
      final modes = zonedCalls.map((call) {
        final args = call.arguments as Map;
        return (args['platformSpecifics'] as Map?)?['scheduleMode'] ??
            args['scheduleMode'];
      }).toList();
      expect(
        modes,
        ['alarmClock', 'exactAllowWhileIdle', 'inexactAllowWhileIdle'],
      );
    });

    test(
        'scheduleDelayed10sTestNotification falls back through alarmClock -> exactAllowWhileIdle -> inexactAllowWhileIdle',
        () async {
      final result = await service.scheduleDelayed10sTestNotification();
      expect(result.success, isTrue);
      expect(result.mode, 'inexact');
      expect(result.isInexact, isTrue);

      final zonedCalls =
          methodCalls.where((call) => call.method == 'zonedSchedule').toList();

      expect(zonedCalls.length, 3);
      final modes = zonedCalls.map((call) {
        final args = call.arguments as Map;
        return (args['platformSpecifics'] as Map?)?['scheduleMode'] ??
            args['scheduleMode'];
      }).toList();
      expect(
        modes,
        ['alarmClock', 'exactAllowWhileIdle', 'inexactAllowWhileIdle'],
      );
    });
  });
}
