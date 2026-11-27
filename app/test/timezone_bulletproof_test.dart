import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:app/core/models/task_model.dart';
import 'package:app/core/models/reminder_model.dart';
import 'package:app/core/services/notification_service.dart';
import 'package:app/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel notifChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const MethodChannel timezoneChannel = MethodChannel('flutter_timezone');

  group('Bulletproof Timezone and ScheduleResult Tests', () {
    final List<MethodCall> notifCalls = [];
    final List<MethodCall> timezoneCalls = [];
    late NotificationService service;

    setUp(() {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      notifCalls.clear();
      timezoneCalls.clear();
      service = NotificationService(allowInTests: true);

      // Mock flutter_local_notifications
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, (MethodCall call) async {
        notifCalls.add(call);
        switch (call.method) {
          case 'initialize':
            return true;
          case 'canScheduleExactNotifications':
            return true;
          case 'requestExactAlarmsPermission':
            return true;
          case 'requestNotificationsPermission':
            return true;
          case 'createNotificationChannel':
            return null;
          case 'zonedSchedule':
            return null;
          default:
            return null;
        }
      });

      // Mock flutter_timezone to throw PlatformException
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(timezoneChannel, (MethodCall call) async {
        timezoneCalls.add(call);
        if (call.method == 'getLocalTimezone') {
          throw PlatformException(
            code: 'UNAVAILABLE',
            message: 'Device timezone service unavailable',
          );
        }
        return null;
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(timezoneChannel, null);
    });

    test(
        'initializes safely and sets fallback timezone when platform timezone lookup throws',
        () async {
      // Must not throw despite FlutterTimezone throwing PlatformException
      await service.initialize();

      // Ensure tz.local is properly initialized and does not throw LateInitializationError
      expect(() => tz.local, returnsNormally);
      expect(tz.local.name, isNotEmpty);
      expect(tz.local.name, anyOf(equals('Africa/Cairo'), equals('UTC')));
    });

    test(
        'schedules 10s test notification successfully when platform timezone lookup throws',
        () async {
      final result = await service.scheduleDelayed10sTestNotification();

      expect(result.success, isTrue);
      expect(result.mode, 'alarmClock');
      expect(result.isAlarmClock, isTrue);
      expect(result.isExact, isTrue);
      expect(result.errorMessage, isNull);

      final zonedCalls =
          notifCalls.where((call) => call.method == 'zonedSchedule').toList();
      expect(zonedCalls.length, 1);
    });

    test('schedules task reminder successfully without throwing', () async {
      final nowUtc = DateTime.now().toUtc();
      final task = TaskModel(
        id: 'task-tz-safe-1',
        title: 'Review Project PR',
        startTime: nowUtc.add(const Duration(minutes: 45)),
        endTime: nowUtc.add(const Duration(hours: 1)),
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: nowUtc,
        updatedAt: nowUtc,
        reminders: [
          ReminderModel(
            id: 'rem-tz-safe-1',
            taskId: 'task-tz-safe-1',
            remindAt: nowUtc.add(const Duration(minutes: 30)),
            offsetMinutes: 15,
            isTriggered: false,
          ),
        ],
      );

      final result = await service.scheduleTaskReminder(task);

      expect(result.success, isTrue);
      expect(result.mode, 'alarmClock');
      expect(result.isAlarmClock, isTrue);
      expect(result.isExact, isTrue);
      expect(result.errorMessage, isNull);

      final zonedCalls =
          notifCalls.where((call) => call.method == 'zonedSchedule').toList();
      expect(zonedCalls.length, 1);
    });

    test('ScheduleResult reports failure and error message on unhandled exception',
        () async {
      // Override zonedSchedule to throw an unexpected exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, (MethodCall call) async {
        if (call.method == 'zonedSchedule') {
          throw PlatformException(
            code: 'INTERNAL_ERROR',
            message: 'Fatal AlarmManager security failure',
          );
        }
        return true;
      });

      final result = await service.scheduleDelayed10sTestNotification();

      expect(result.success, isFalse);
      expect(result.mode, 'none');
      expect(result.errorMessage, contains('Fatal AlarmManager security failure'));
    });

    test('compactNotificationError truncates stack traces to first line / 140 chars',
        () {
      expect(compactNotificationError(null), '');
      expect(compactNotificationError('   \n  '), '');
      const stackTrace =
          'PlatformException(error, java.lang.RuntimeException: Missing type parameter., null)\n\tat com.google.gson.internal.\$Gson\$Types.getSuperclassTypeParameter';
      expect(
        compactNotificationError(stackTrace),
        'PlatformException(error, java.lang.RuntimeException: Missing type parameter., null)',
      );
      final longError = 'A' * 200;
      final compacted = compactNotificationError(longError);
      expect(compacted.length, 140);
      expect(compacted.endsWith('...'), isTrue);
    });
  });
}
