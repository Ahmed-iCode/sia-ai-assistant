import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/task_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/google_calendar_helper.dart';
import '../tasks_provider.dart';

class TaskCard extends ConsumerWidget {
  final TaskModel task;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return AppColors.priorityUrgent;
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  String _getPriorityLabel(TaskPriority priority, AppLocalizations l10n) {
    switch (priority) {
      case TaskPriority.urgent:
        return l10n.strings.priorityUrgent;
      case TaskPriority.high:
        return l10n.strings.priorityHigh;
      case TaskPriority.medium:
        return l10n.strings.priorityMedium;
      case TaskPriority.low:
        return l10n.strings.priorityLow;
    }
  }

  String _getRecurrenceLabel(String type, AppLocalizations l10n) {
    switch (type.toLowerCase()) {
      case 'daily':
        return l10n.strings.recurrenceDaily;
      case 'weekly':
        return l10n.strings.recurrenceWeekly;
      case 'monthly':
        return l10n.strings.recurrenceMonthly;
      default:
        return l10n.strings.recurrenceLabel;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(task.priority);
    final isCompleted = task.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              : (isDark ? AppColors.darkBorderSubtle.withAlpha(100) : AppColors.lightBorder),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Source, Time, Priority & Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Completion checkbox button
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onToggleComplete,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppColors.success
                              : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                          border: Border.all(
                            color: isCompleted
                                ? AppColors.success
                                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                            width: 1.5,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Time window & Duration
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 14,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormatter.formatTimeWindow(task.startTime, task.endTime, context),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              DateFormatter.formatDuration(task.duration, l10n.locale.languageCode),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                          if (task.isRecurring)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(isDark ? 35 : 20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withAlpha(60),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.repeat, size: 11, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getRecurrenceLabel(task.recurrenceType, l10n),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Source indicator (Voice vs Manual)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: task.isVoiceCreated
                            ? AppColors.primary.withAlpha(isDark ? 40 : 25)
                            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.isVoiceCreated ? LucideIcons.mic : LucideIcons.edit3,
                            size: 12,
                            color: task.isVoiceCreated
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.isVoiceCreated ? l10n.strings.taskSourceVoice : l10n.strings.taskSourceManual,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: task.isVoiceCreated
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Priority Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: priorityColor.withAlpha(80), width: 1),
                      ),
                      child: Text(
                        _getPriorityLabel(task.priority, l10n),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: priorityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),

                    // 1-Click Add to Google Calendar Icon Button
                    IconButton(
                      tooltip: l10n.strings.addToGoogleCalendar,
                      icon: const Icon(LucideIcons.calendarPlus, size: 17),
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => GoogleCalendarHelper.openInGoogleCalendar(task),
                    ),

                    // Context Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        LucideIcons.moreVertical,
                        size: 18,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                        if (value == 'toggle') onToggleComplete();
                        if (value == 'google_calendar') GoogleCalendarHelper.openInGoogleCalendar(task);
                        if (value == 'stop_recurrence') _showStopRecurrenceDialog(context, ref, l10n);
                      },
                      itemBuilder: (context) => [
                        if (task.recurrenceGroupId != null && task.isRecurrenceActive)
                          PopupMenuItem(
                            value: 'stop_recurrence',
                            child: Row(
                              children: [
                                const Icon(LucideIcons.repeat, size: 16, color: AppColors.warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.strings.stopRepeating,
                                    style: const TextStyle(color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'google_calendar',
                          child: Row(
                            children: [
                                const Icon(LucideIcons.calendarPlus, size: 16, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(l10n.strings.addToGoogleCalendar),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                isCompleted ? LucideIcons.rotateCcw : LucideIcons.check,
                                size: 16,
                                color: isCompleted ? AppColors.warning : AppColors.success,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(isCompleted ? l10n.strings.markIncomplete : l10n.strings.markComplete),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(LucideIcons.edit2, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(l10n.strings.editTask),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.strings.deleteTask,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Title
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 38),
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ),

                // Description (if present)
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 38),
                    child: Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],

                // Reminders and tags bar
                if (task.reminders.isNotEmpty || task.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 38),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Reminders badge
                        for (final reminder in task.reminders)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(isDark ? 30 : 20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.bell, size: 11, color: AppColors.warning),
                                const SizedBox(width: 4),
                                Text(
                                  '${l10n.strings.reminderLabel}: ${reminder.offsetMinutes}m',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Tags
                        for (final tag in task.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStopRecurrenceDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.repeat, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.strings.stopRepeatingConfirmTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.strings.stopRepeatingConfirmDesc,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.strings.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(tasksProvider.notifier).stopRecurrence(
                      task.recurrenceGroupId!,
                      deleteFuture: true,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.strings.stopRepeating),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('ApiException: ', '')),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.strings.stopRepeatingConfirmButton),
          ),
        ],
      ),
    );
  }
}
