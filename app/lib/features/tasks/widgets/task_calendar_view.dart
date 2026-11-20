import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/task_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../tasks_provider.dart';
import 'task_card.dart';
import 'task_form_sheet.dart';

/// Monthly, 2-Weeks and Weekly interactive calendar view with priority dot markers,
/// bilingual RTL/LTR typography, Apple/Linear styling, and direct day agenda inspection.
class TaskCalendarView extends ConsumerStatefulWidget {
  const TaskCalendarView({super.key});

  @override
  ConsumerState<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends ConsumerState<TaskCalendarView> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _focusedDay = _selectedDay;
  }

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

  List<TaskModel> _getTasksForDay(List<TaskModel> tasks, DateTime day) {
    return tasks.where((t) {
      return t.startTime.year == day.year &&
          t.startTime.month == day.month &&
          t.startTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';

    final tasksAsync = ref.watch(tasksProvider);
    final allTasks = tasksAsync.value ?? [];
    final dayTasks = _getTasksForDay(allTasks, _selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Calendar Container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: TableCalendar<TaskModel>(
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2035, 12, 31),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              locale: locale.languageCode,
              startingDayOfWeek: isArabic ? StartingDayOfWeek.saturday : StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: (day) => _getTasksForDay(allTasks, day),
              availableCalendarFormats: {
                CalendarFormat.month: l10n.strings.formatMonth,
                CalendarFormat.twoWeeks: l10n.strings.formatTwoWeeks,
                CalendarFormat.week: l10n.strings.formatWeek,
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                ref.read(tasksFilterProvider.notifier).setSelectedDate(selectedDay);
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                formatButtonTextStyle: theme.textTheme.labelSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                leftChevronIcon: Icon(
                  isArabic ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                  size: 18,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                rightChevronIcon: Icon(
                  isArabic ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
                  size: 18,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                headerPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                weekendTextStyle: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                selectedDecoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                markerSize: 5,
                markersMaxCount: 4,
                markersAlignment: Alignment.bottomCenter,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, tasks) {
                  if (tasks.isEmpty) return null;
                  final displayTasks = tasks.take(4).toList();
                  return Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: displayTasks.map((task) {
                        final color = _getPriorityColor(task.priority);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Selected Day Agenda Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Title and Task count pill
              Row(
                children: [
                  Text(
                    DateFormatter.formatDate(_selectedDay, context),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withAlpha(80)),
                    ),
                    child: Text(
                      '${dayTasks.length} ${l10n.strings.tasksCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              // "+ Add Task on This Day" Button
              ElevatedButton.icon(
                onPressed: () => TaskFormSheet.show(context, initialDate: _selectedDay),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: Text(l10n.strings.addTaskOnDay),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Day Agenda List / Empty State
        if (dayTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.calendarCheck,
                      size: 26,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.strings.noTasksForDay,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => TaskFormSheet.show(context, initialDate: _selectedDay),
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: Text(l10n.strings.addTaskOnDay),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: dayTasks.length,
            itemBuilder: (context, index) {
              final task = dayTasks[index];
              return TaskCard(
                task: task,
                onToggleComplete: () =>
                    ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
                onEdit: () => TaskFormSheet.show(context, task: task),
                onDelete: () =>
                    ref.read(tasksProvider.notifier).deleteTask(task.id),
              );
            },
          ),
      ],
    );
  }
}
