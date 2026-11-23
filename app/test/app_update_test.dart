import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/l10n/app_localizations.dart';
import 'package:app/core/services/app_update_service.dart';
import 'package:app/core/widgets/app_update_dialog.dart';

void main() {
  group('AppUpdateInfo Model Tests', () {
    test('fromJson parses snake_case JSON correctly', () {
      final json = {
        'version_name': '1.2.0',
        'build_number': 42,
        'download_url': 'https://github.com/Ahmed-iCode/sia-ai-assistant/releases/latest/download/Sia.apk',
        'release_notes': 'Fixed notification sound and improved voice speed.',
        'published_at': '2026-11-23T10:00:00Z',
      };

      final info = AppUpdateInfo.fromJson(json);
      expect(info.versionName, '1.2.0');
      expect(info.buildNumber, 42);
      expect(info.downloadUrl, 'https://github.com/Ahmed-iCode/sia-ai-assistant/releases/latest/download/Sia.apk');
      expect(info.releaseNotes, 'Fixed notification sound and improved voice speed.');
      expect(info.publishedAt.toUtc(), DateTime.utc(2026, 11, 23, 10, 0, 0));
    });

    test('fromJson parses string build_number safely', () {
      final json = {
        'version_name': '2.0.0',
        'build_number': '55',
        'download_url': 'https://example.com/Sia.apk',
        'release_notes': 'Major update',
      };

      final info = AppUpdateInfo.fromJson(json);
      expect(info.versionName, '2.0.0');
      expect(info.buildNumber, 55);
    });

    test('fromJson provides safe defaults when fields are missing', () {
      final json = <String, dynamic>{};
      final info = AppUpdateInfo.fromJson(json);

      expect(info.versionName, '1.0.0');
      expect(info.buildNumber, 0);
      expect(info.downloadUrl, isNotEmpty);
      expect(info.releaseNotes, isNotEmpty);
      expect(info.publishedAt, isNotNull);
    });

    test('toJson produces expected structure', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0, 0);
      final info = AppUpdateInfo(
        versionName: '1.0.1',
        buildNumber: 15,
        downloadUrl: 'https://example.com/Sia.apk',
        releaseNotes: 'Performance enhancements',
        publishedAt: now,
      );

      final json = info.toJson();
      expect(json['version_name'], '1.0.1');
      expect(json['build_number'], 15);
      expect(json['download_url'], 'https://example.com/Sia.apk');
      expect(json['release_notes'], 'Performance enhancements');
      expect(json['published_at'], '2026-11-23T12:00:00.000Z');
    });

    test('isNewerVersion logic', () {
      expect(AppUpdateInfo.isNewerVersion(localBuildNumber: 10, remoteBuildNumber: 11), isTrue);
      expect(AppUpdateInfo.isNewerVersion(localBuildNumber: 10, remoteBuildNumber: 10), isFalse);
      expect(AppUpdateInfo.isNewerVersion(localBuildNumber: 15, remoteBuildNumber: 10), isFalse);
    });
  });

  group('AppUpdateService Dismissal and Suppression Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('dismissUpdate stores build number in SharedPreferences', () async {
      final service = AppUpdateService.instance;
      await service.dismissUpdate(42);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppUpdateService.keyDismissedUpdateBuild), 42);
    });

    test('markUpdateNotified and wasUpdateNotified work properly', () async {
      final service = AppUpdateService.instance;
      expect(await service.wasUpdateNotified(99), isFalse);

      await service.markUpdateNotified(99);
      expect(await service.wasUpdateNotified(99), isTrue);
      expect(await service.wasUpdateNotified(100), isFalse);
    });
  });

  group('AppUpdateDialog Widget Tests', () {
    final sampleInfo = AppUpdateInfo(
      versionName: '1.1.0',
      buildNumber: 25,
      downloadUrl: 'https://github.com/Ahmed-iCode/sia-ai-assistant/releases/latest/download/Sia.apk',
      releaseNotes: 'دعم التذكيرات القصيرة وإصلاحات الإشعارات في الخلفية.',
      publishedAt: DateTime.utc(2026, 11, 23, 10, 0, 0),
    );

    testWidgets('Renders update dialog in Arabic with version and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          home: Scaffold(
            body: AppUpdateDialog(info: sampleInfo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تحديث جديد لتطبيق Sia'), findsOneWidget);
      expect(find.text('v1.1.0 (Build 25)'), findsOneWidget);
      expect(find.text('دعم التذكيرات القصيرة وإصلاحات الإشعارات في الخلفية.'), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
    });

    testWidgets('Renders update dialog in English', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          home: Scaffold(
            body: AppUpdateDialog(info: sampleInfo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Sia Update Available'), findsOneWidget);
      expect(find.text('v1.1.0 (Build 25)'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });
  });
}
