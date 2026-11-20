import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/reminder_model.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../tasks_provider.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  final TaskModel? initialTask;
  final DateTime? initialDate;

  const TaskFormSheet({super.key, this.initialTask, this.initialDate});

  static Future<void> show(BuildContext context, {TaskModel? task, DateTime? initialDate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskFormSheet(initialTask: task, initialDate: initialDate),
    );
  }

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TaskPriority _priority;
  late int _reminderOffset;
  bool _hasConflict = false;
  String? _conflictingTaskTitle;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descController = TextEditingController(text: task?.description ?? '');

    final now = DateTime.now();
    _selectedDate = task?.startTime ?? widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _startTime = task != null
        ? TimeOfDay(hour: task.startTime.hour, minute: task.startTime.minute)
        : TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    _endTime = task != null
        ? TimeOfDay(hour: task.endTime.hour, minute: task.endTime.minute)
        : TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);
    _priority = task?.priority ?? TaskPriority.medium;
    _reminderOffset = task?.reminders.isNotEmpty == true
        ? task!.reminders.first.offsetMinutes
        : 30;

    _checkTimeConflict();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  DateTime _buildStartDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime _buildEndDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );
  }

  Future<void> _checkTimeConflict() async {
    final start = _buildStartDateTime();
    final end = _buildEndDateTime();

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      setState(() {
        _hasConflict = false;
        _conflictingTaskTitle = null;
      });
      return;
    }

    final repo = ref.read(taskRepositoryProvider);
    final conflicts = await repo.checkConflicts(
      startTime: start,
      endTime: end,
      excludeTaskId: widget.initialTask?.id,
    );

    if (mounted) {
      setState(() {
        _hasConflict = conflicts.isNotEmpty;
        _conflictingTaskTitle = conflicts.isNotEmpty ? conflicts.first.title : null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _checkTimeConflict();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      _checkTimeConflict();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
      _checkTimeConflict();
    }
  }

  Future<void> _saveTask({bool force = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final start = _buildStartDateTime();
    final end = _buildEndDateTime();

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).strings.validationTimeOrder),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final taskToSave = (widget.initialTask ??
            TaskModel(
              id: '',
              title: '',
              startTime: start,
              endTime: end,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      startTime: start,
      endTime: end,
      priority: _priority,
      reminders: _reminderOffset > 0
          ? [
              ReminderModel(
                id: 'rem-${DateTime.now().millisecondsSinceEpoch}',
                taskId: widget.initialTask?.id ?? '',
                remindAt: start.subtract(Duration(minutes: _reminderOffset)),
                offsetMinutes: _reminderOffset,
              ),
            ]
          : [],
    );

    try {
      if (widget.initialTask == null) {
        await ref.read(tasksProvider.notifier).createTask(taskToSave, force: force);
      } else {
        await ref.read(tasksProvider.notifier).updateTask(taskToSave);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (e is ConflictException) {
        if (mounted) {
          _showConflictResolutionDialog(taskToSave, e);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('ApiException: ', '')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showConflictResolutionDialog(TaskModel taskToSave, ConflictException conflict) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text('Schedule Conflict', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.conflictingTask != null
                  ? 'Overlaps with: "${conflict.conflictingTask!.title}" (${DateFormat('hh:mm a').format(conflict.conflictingTask!.startTime)} - ${DateFormat('hh:mm a').format(conflict.conflictingTask!.endTime)})'
                  : conflict.message,
              style: const TextStyle(fontSize: 13),
            ),
            if (conflict.alternativeFreeSlots.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Available Alternative Slots:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: conflict.alternativeFreeSlots.map((slot) {
                  final label =
                      '${DateFormat('hh:mm a').format(slot.start)} - ${DateFormat('hh:mm a').format(slot.end)}';
                  return ActionChip(
                    avatar: const Icon(LucideIcons.clock, size: 12),
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedDate = slot.start;
                        _startTime = TimeOfDay(hour: slot.start.hour, minute: slot.start.minute);
                        _endTime = TimeOfDay(hour: slot.end.hour, minute: slot.end.minute);
                      });
                      _saveTask(force: false);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveTask(force: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Force Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialTask != null;

    final priorityOptions = [
      (TaskPriority.low, l10n.strings.priorityLow, AppColors.priorityLow),
      (TaskPriority.medium, l10n.strings.priorityMedium, AppColors.priorityMedium),
      (TaskPriority.high, l10n.strings.priorityHigh, AppColors.priorityHigh),
      (TaskPriority.urgent, l10n.strings.priorityUrgent, AppColors.priorityUrgent),
    ];

    final reminderOptions = [
      (0, 'بدون / None'),
      (15, '15m'),
      (30, '30m'),
      (60, '1h'),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              // Title Header & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? l10n.strings.editTaskTitle : l10n.strings.addTask,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Conflict Warning Alert Banner
              if (_hasConflict) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.errorBgDark.withAlpha(isDark ? 80 : 30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${l10n.strings.conflictDetectedWarning} ($_conflictingTaskTitle)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Task Title Input
              Text(
                l10n.strings.taskTitleLabel,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return l10n.strings.validationTitleRequired;
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: l10n.strings.taskTitleHint,
                ),
              ),
              const SizedBox(height: 14),

              // Task Description Input
              Text(
                l10n.strings.taskDescLabel,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: l10n.strings.taskDescHint,
                ),
              ),
              const SizedBox(height: 16),

              // Date & Time Row
              Row(
                children: [
                  // Date Picker Button
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('d MMM yyyy', l10n.locale.languageCode).format(_selectedDate),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Start Time Button
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.clock, size: 14, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _startTime.format(context),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // End Time Button
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.clock, size: 14, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _endTime.format(context),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Priority Selector
              Text(
                l10n.strings.priorityLabel,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: priorityOptions.map((opt) {
                  final isSelected = _priority == opt.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() => _priority = opt.$1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? opt.$3.withAlpha(isDark ? 60 : 35)
                                : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? opt.$3
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt.$2,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? opt.$3
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Reminder Selector
              Text(
                l10n.strings.reminderOffsetLabel,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: reminderOptions.map((opt) {
                  final isSelected = _reminderOffset == opt.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() => _reminderOffset = opt.$1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.warning.withAlpha(isDark ? 50 : 30)
                                : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.warning
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt.$2,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? AppColors.warning
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save & Cancel Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.strings.cancelButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveTask,
                      child: Text(l10n.strings.saveButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
