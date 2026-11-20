import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';

/// Utilities to build and launch 1-Click "Add to Google Calendar" URLs.
class GoogleCalendarHelper {
  static const String _calendarBaseUrl = 'https://calendar.google.com/calendar/render';

  /// Formats a [DateTime] into Google Calendar's required UTC format: YYYYMMDDTHHMMSSZ.
  static String formatGoogleDateTime(DateTime dt) {
    final u = dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    final h = u.hour.toString().padLeft(2, '0');
    final min = u.minute.toString().padLeft(2, '0');
    final s = u.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }

  /// Builds a [Uri] targeting Google Calendar's event creation template.
  static Uri buildGoogleCalendarUrl(TaskModel task, {String timezone = 'Africa/Cairo'}) {
    final dates = '${formatGoogleDateTime(task.startTime)}/${formatGoogleDateTime(task.endTime)}';

    final detailsParts = <String>[];
    if (task.description != null && task.description!.trim().isNotEmpty) {
      detailsParts.add(task.description!.trim());
    }
    detailsParts.add('Priority: ${task.priority.name.toUpperCase()}');
    if (task.tags.isNotEmpty) {
      detailsParts.add('Tags: ${task.tags.map((t) => '#$t').join(' ')}');
    }
    if (task.isVoiceCreated) {
      detailsParts.add('Created with AI Task Assistant (Voice)');
    }

    final queryParameters = <String, String>{
      'action': 'TEMPLATE',
      'text': task.title,
      'dates': dates,
      'details': detailsParts.join('\n\n'),
      'ctz': timezone.isNotEmpty ? timezone : 'Africa/Cairo',
    };

    return Uri.parse(_calendarBaseUrl).replace(queryParameters: queryParameters);
  }

  /// Launches Google Calendar in a new browser tab on Web or in the external
  /// calendar app on Android/iOS.
  static Future<bool> openInGoogleCalendar(TaskModel task, {String timezone = 'Africa/Cairo'}) async {
    final uri = buildGoogleCalendarUrl(task, timezone: timezone);
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      debugPrint('[GoogleCalendarHelper] Could not launch URL: $e');
      return false;
    }
  }
}
