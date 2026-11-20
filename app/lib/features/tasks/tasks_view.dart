import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/models/task_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'tasks_provider.dart';
import 'widgets/task_card.dart';
import 'widgets/task_calendar_view.dart';
import 'widgets/task_date_tabs.dart';
import 'widgets/task_filter_bar.dart';
import 'widgets/task_form_sheet.dart';

class TasksView extends ConsumerWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filter = ref.watch(tasksFilterProvider);
    final filteredTasks = ref.watch(filteredTasksProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Top Header & Add button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // View Title and Task count pill
                      Row(
                        children: [
                          Text(
                            l10n.strings.navSchedule,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withAlpha(80),
                              ),
                            ),
                            child: Text(
                              '${filteredTasks.length} ${l10n.strings.tasksCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Manual Add Task Button
                      ElevatedButton.icon(
                        onPressed: () => TaskFormSheet.show(context),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(l10n.strings.addTask),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Mode Tabs (Today, This Week, Timeline, Calendar)
                  const TaskDateTabs(),
                  const SizedBox(height: 14),

                  // Filter & Search Bar (displayed for list/timeline views)
                  if (filter.viewMode != TaskViewMode.calendar) ...[
                    const TaskFilterBar(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Content body
          tasksAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: _buildErrorCard(context, ref, err),
              ),
            ),
            data: (_) {
              // Interactive Calendar View Mode
              if (filter.viewMode == TaskViewMode.calendar) {
                return const SliverToBoxAdapter(
                  child: TaskCalendarView(),
                );
              }

              if (filteredTasks.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.calendarCheck,
                              size: 32,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.strings.noTasksToday,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => TaskFormSheet.show(context),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: Text(l10n.strings.addTask),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Timeline View vs Standard Card List
              if (filter.viewMode == TaskViewMode.timeline) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = filteredTasks[index];
                        return _buildTimelineItem(context, task, ref, index == filteredTasks.length - 1);
                      },
                      childCount: filteredTasks.length,
                    ),
                  ),
                );
              }

              // Standard Cards List
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final task = filteredTasks[index];
                      return TaskCard(
                        task: task,
                        onToggleComplete: () {
                          ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
                        },
                        onEdit: () {
                          TaskFormSheet.show(context, task: task);
                        },
                        onDelete: () {
                          ref.read(tasksProvider.notifier).deleteTask(task.id);
                        },
                      );
                    },
                    childCount: filteredTasks.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref, Object err) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    final errString = err.toString();
    final is401 = errString.contains('401') || errString.toLowerCase().contains('unauthenticated');

    final title = is401
        ? (isArabic ? 'انتهت الجلسة أو يلزم تسجيل الدخول' : 'Session Expired or Sign In Required')
        : (isArabic ? 'تعذر تحميل المهام' : 'Unable to Load Tasks');

    final message = is401
        ? (isArabic
            ? 'يرجى تسجيل الدخول للوصول إلى جدول مهامك ومزامنتها مع الخادم.'
            : 'Please sign in to access your task schedule and synchronize with the server.')
        : (isArabic
            ? 'تأكد من تشغيل خادم المهام والاتصال بالإنترنت ثم حاول مجدداً.'
            : 'Please check your connection or server status and try again.');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: is401
                  ? AppColors.primary.withAlpha(80)
                  : AppColors.error.withAlpha(80),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (is401 ? AppColors.primary : AppColors.error).withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  is401 ? LucideIcons.logIn : LucideIcons.alertCircle,
                  color: is401 ? AppColors.primary : AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (is401)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      icon: const Icon(LucideIcons.logIn, size: 16),
                      label: Text(isArabic ? 'تسجيل الدخول' : 'Sign In'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(tasksProvider.notifier).refresh();
                      },
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, TaskModel task, WidgetRef ref, bool isLast) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Time & connector line
        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormatter.formatTime(task.startTime, context),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                DateFormatter.formatTime(task.endTime, context),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Timeline Node & Vertical connecting line
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted ? AppColors.success : AppColors.primary,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 90,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Right side: Compact Task Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TaskCard(
              task: task,
              onToggleComplete: () {
                ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
              },
              onEdit: () {
                TaskFormSheet.show(context, task: task);
              },
              onDelete: () {
                ref.read(tasksProvider.notifier).deleteTask(task.id);
              },
            ),
          ),
        ),
      ],
    );
  }
}
