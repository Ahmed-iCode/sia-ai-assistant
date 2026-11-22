import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/extracted_task_draft_model.dart';
import '../../../core/models/task_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';

class BatchTaskPreviewCard extends StatefulWidget {
  final List<ExtractedTaskDraftModel> tasks;
  final bool isExecuted;
  final Future<void> Function(List<ExtractedTaskDraftModel> selectedDrafts)? onConfirm;

  const BatchTaskPreviewCard({
    super.key,
    required this.tasks,
    this.isExecuted = false,
    this.onConfirm,
  });

  @override
  State<BatchTaskPreviewCard> createState() => _BatchTaskPreviewCardState();
}

class _BatchTaskPreviewCardState extends State<BatchTaskPreviewCard> {
  late List<ExtractedTaskDraftModel> _drafts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _drafts = List.from(widget.tasks);
  }

  @override
  void didUpdateWidget(covariant BatchTaskPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _drafts = List.from(widget.tasks);
    }
  }

  int get _selectedCount => _drafts.where((d) => d.isSelected).length;

  void _toggleAll(bool selectAll) {
    setState(() {
      _drafts = _drafts.map((d) => d.copyWith(isSelected: selectAll)).toList();
    });
  }

  Future<void> _handleConfirm() async {
    final selected = _drafts.where((d) => d.isSelected).toList();
    if (selected.isEmpty || _isSaving || widget.onConfirm == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onConfirm!(selected);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save tasks: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return AppColors.error;
      case TaskPriority.high:
        return AppColors.warning;
      case TaskPriority.medium:
        return AppColors.primary;
      case TaskPriority.low:
        return AppColors.darkTextMuted;
    }
  }

  String _priorityText(TaskPriority priority, AppLocalizations l10n) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = l10n.isArabic;

    if (widget.isExecuted) {
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
                  l10n.strings.cardBatchSuccess,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_drafts.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final allSelected = _drafts.isNotEmpty && _selectedCount == _drafts.length;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withAlpha(isDark ? 100 : 60),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon, Title, and Select All toggle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.calendarCheck2, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.strings.cardBatchTasksTitle} (${_drafts.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (_drafts.length > 1)
                TextButton(
                  onPressed: () => _toggleAll(!allSelected),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    allSelected
                        ? (isArabic ? 'إلغاء التحديد' : 'Deselect All')
                        : (isArabic ? 'تحديد الكل' : 'Select All'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // List of Extracted Task Drafts with Checkboxes
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _drafts.length,
            separatorBuilder: (context, index) => Divider(
              height: 12,
              thickness: 0.8,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            itemBuilder: (context, index) {
              final draft = _drafts[index];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _drafts[index] = draft.copyWith(isSelected: !draft.isSelected);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: draft.isSelected,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              _drafts[index] = draft.copyWith(isSelected: val ?? false);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Task Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.title,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: draft.isSelected ? null : TextDecoration.lineThrough,
                                color: draft.isSelected
                                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormatter.formatDate(draft.startTime, context),
                                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.clock, size: 12, color: AppColors.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormatter.formatTimeWindow(
                                        draft.startTime,
                                        draft.endTime,
                                        context,
                                      ),
                                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                                // Priority badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _priorityColor(draft.priority).withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _priorityText(draft.priority, l10n),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _priorityColor(draft.priority),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (draft.category != null && draft.category!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      draft.category!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Primary Confirm Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedCount > 0 && !_isSaving) ? _handleConfirm : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.check, size: 16),
              label: Text(
                _selectedCount > 0
                    ? (isArabic
                        ? 'تأكيد وإضافة ($_selectedCount) مهام'
                        : 'Confirm & Add ($_selectedCount) Tasks')
                    : (isArabic ? 'اختر مهمة واحدة على الأقل' : 'Select at least one task'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
