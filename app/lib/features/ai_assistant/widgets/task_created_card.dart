import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/task_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/google_calendar_helper.dart';
import '../../settings/settings_provider.dart';
import '../../tasks/widgets/task_form_sheet.dart';

class TaskCreatedCard extends ConsumerWidget {
  final TaskModel task;
  final bool isUndone;
  final VoidCallback onUndo;

  const TaskCreatedCard({
    super.key,
    required this.task,
    required this.isUndone,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isUndone) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.undo, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              l10n.strings.actionUndoneNotification,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withAlpha(isDark ? 100 : 70),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Success Icon & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.checkCheck, size: 16, color: AppColors.success),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.strings.cardTaskCreatedTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Task Title
          Text(
            task.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),

          // Time & Date badges
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.calendar, size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.formatDate(task.startTime, context),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock, size: 13, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.formatTimeWindow(task.startTime, task.endTime, context),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (task.reminders.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.bell, size: 13, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '${task.reminders.first.offsetMinutes}m',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Add to Google Calendar, Undo & Edit
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Add to Google Calendar
              OutlinedButton.icon(
                onPressed: () {
                  final tz = ref.read(settingsProvider).timezone;
                  GoogleCalendarHelper.openInGoogleCalendar(task, timezone: tz);
                },
                icon: const Icon(LucideIcons.calendarPlus, size: 14, color: AppColors.primary),
                label: Text(l10n.strings.addToGoogleCalendar),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),

              // Undo Button
              OutlinedButton.icon(
                onPressed: onUndo,
                icon: const Icon(LucideIcons.undo2, size: 14),
                label: Text(l10n.strings.cardUndo),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),

              // Edit Button
              ElevatedButton.icon(
                onPressed: () {
                  TaskFormSheet.show(context, task: task);
                },
                icon: const Icon(LucideIcons.edit2, size: 14),
                label: Text(l10n.strings.cardEdit),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
