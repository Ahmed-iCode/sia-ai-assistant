import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../tasks_provider.dart';

class TaskFilterBar extends ConsumerStatefulWidget {
  const TaskFilterBar({super.key});

  @override
  ConsumerState<TaskFilterBar> createState() => _TaskFilterBarState();
}

class _TaskFilterBarState extends ConsumerState<TaskFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(tasksFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statusFilters = [
      (TaskStatusFilter.all, l10n.strings.filterAll),
      (TaskStatusFilter.pending, l10n.strings.filterPending),
      (TaskStatusFilter.inProgress, l10n.strings.filterInProgress),
      (TaskStatusFilter.completed, l10n.strings.filterCompleted),
    ];

    final priorityFilters = [
      (TaskPriorityFilter.all, l10n.strings.priorityAll),
      (TaskPriorityFilter.urgent, l10n.strings.priorityUrgent),
      (TaskPriorityFilter.high, l10n.strings.priorityHigh),
      (TaskPriorityFilter.medium, l10n.strings.priorityMedium),
      (TaskPriorityFilter.low, l10n.strings.priorityLow),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (val) {
            ref.read(tasksFilterProvider.notifier).setSearchQuery(val);
          },
          decoration: InputDecoration(
            hintText: l10n.strings.searchPlaceholder,
            prefixIcon: const Icon(LucideIcons.search, size: 18),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(tasksFilterProvider.notifier).setSearchQuery('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Status & Priority Filters scrollable row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Status filters
              for (final item in statusFilters) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    selected: filter.statusFilter == item.$1,
                    label: Text(item.$2),
                    showCheckmark: false,
                    onSelected: (_) {
                      ref.read(tasksFilterProvider.notifier).setStatusFilter(item.$1);
                    },
                    selectedColor: AppColors.primary.withAlpha(isDark ? 50 : 35),
                    labelStyle: TextStyle(
                      color: filter.statusFilter == item.$1
                          ? AppColors.primary
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      fontWeight: filter.statusFilter == item.$1 ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: filter.statusFilter == item.$1
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
              ],

              // Vertical separator
              Container(
                height: 24,
                width: 1,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),

              // Priority Dropdown Filter
              PopupMenuButton<TaskPriorityFilter>(
                tooltip: l10n.strings.priorityLabel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: filter.priorityFilter != TaskPriorityFilter.all
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.slidersHorizontal,
                        size: 14,
                        color: filter.priorityFilter != TaskPriorityFilter.all
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        priorityFilters.firstWhere((p) => p.$1 == filter.priorityFilter).$2,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: filter.priorityFilter != TaskPriorityFilter.all
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronDown, size: 12),
                    ],
                  ),
                ),
                onSelected: (priority) {
                  ref.read(tasksFilterProvider.notifier).setPriorityFilter(priority);
                },
                itemBuilder: (context) => [
                  for (final p in priorityFilters)
                    PopupMenuItem(
                      value: p.$1,
                      child: Text(p.$2),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
