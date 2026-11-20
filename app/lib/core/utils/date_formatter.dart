import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatTime(DateTime time, BuildContext context) {
    final localTime = time.toLocal();
    final is24 = MediaQuery.of(context).alwaysUse24HourFormat;
    final locale = Localizations.localeOf(context).languageCode;
    final format = is24 ? DateFormat('HH:mm', locale) : DateFormat('hh:mm a', locale);
    return format.format(localTime);
  }

  static String formatTimeWindow(DateTime start, DateTime end, BuildContext context) {
    return '${formatTime(start.toLocal(), context)} - ${formatTime(end.toLocal(), context)}';
  }

  static String formatDate(DateTime date, BuildContext context) {
    final localDate = date.toLocal();
    final locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(localDate.year, localDate.month, localDate.day);

    if (target.isAtSameMomentAs(today)) {
      return locale == 'ar' ? 'اليوم' : 'Today';
    } else if (target.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return locale == 'ar' ? 'غداً' : 'Tomorrow';
    } else if (target.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return locale == 'ar' ? 'أمس' : 'Yesterday';
    }

    return DateFormat('EEE, d MMM', locale).format(localDate);
  }

  static String formatDuration(Duration duration, String locale) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (locale == 'ar') {
      if (hours > 0 && minutes > 0) {
        return '$hours س $minutes د';
      } else if (hours > 0) {
        return '$hours س';
      } else {
        return '$minutes د';
      }
    } else {
      if (hours > 0 && minutes > 0) {
        return '${hours}h ${minutes}m';
      } else if (hours > 0) {
        return '${hours}h';
      } else {
        return '${minutes}m';
      }
    }
  }

  static String formatMinutes(int minutes, String locale) {
    return formatDuration(Duration(minutes: minutes), locale);
  }
}
