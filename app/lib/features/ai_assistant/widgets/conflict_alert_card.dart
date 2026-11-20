import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/ai_action_card_model.dart';
import '../../../core/models/free_slot_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../tasks/tasks_provider.dart';

class ConflictAlertCard extends ConsumerWidget {
  final AiActionCardModel actionCard;
  final Function(FreeSlotModel) onSelectSlot;

  const ConflictAlertCard({
    super.key,
    required this.actionCard,
    required this.onSelectSlot,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final conflict = actionCard.conflictingTask;
    final proposed = actionCard.task;
    final freeSlots = actionCard.freeSlots;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withAlpha(isDark ? 110 : 70),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Alert
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.error),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.strings.cardConflictTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Conflicting Task Info
          if (conflict != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendarX, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conflict.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormatter.formatTimeWindow(conflict.startTime, conflict.endTime, context),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Message & Alternative Slots Header
          Text(
            l10n.strings.cardConflictDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Clickable Alternative Free-Slot Chips
          if (freeSlots.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: freeSlots.map((slot) {
                final timeLabel = DateFormatter.formatTimeWindow(slot.start, slot.end, context);
                final durationLabel = DateFormatter.formatMinutes(slot.durationMinutes, l10n.locale.languageCode);

                return ActionChip(
                  backgroundColor: AppColors.primary.withAlpha(isDark ? 35 : 20),
                  side: BorderSide(color: AppColors.primary.withAlpha(80)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  avatar: const Icon(LucideIcons.calendarPlus, size: 14, color: AppColors.primary),
                  label: Text('$timeLabel ($durationLabel)'),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  onPressed: () {
                    if (proposed != null) {
                      final newDuration = proposed.duration;
                      final updatedTask = proposed.copyWith(
                        startTime: slot.start,
                        endTime: slot.start.add(newDuration),
                      );
                      ref.read(tasksProvider.notifier).createTask(updatedTask);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.strings.actionCompletedNotification),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                    onSelectSlot(slot);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
