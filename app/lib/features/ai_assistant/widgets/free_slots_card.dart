import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/free_slot_model.dart';
import '../../../core/models/task_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../tasks/widgets/task_form_sheet.dart';

class FreeSlotsCard extends ConsumerWidget {
  final List<FreeSlotModel> freeSlots;

  const FreeSlotsCard({
    super.key,
    required this.freeSlots,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.secondary.withAlpha(isDark ? 90 : 60),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.sparkles, size: 16, color: AppColors.secondary),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.strings.cardFreeSlotsTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            l10n.strings.cardAvailableSlotsHeader,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Slots list
          for (final slot in freeSlots)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatter.formatTimeWindow(slot.start, slot.end, context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${l10n.strings.durationLabel}: ${DateFormatter.formatMinutes(slot.durationMinutes, l10n.locale.languageCode)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Schedule Here button
                  ElevatedButton.icon(
                    onPressed: () {
                      final prefilledTask = TaskModel(
                        id: '',
                        title: '',
                        startTime: slot.start,
                        endTime: slot.start.add(const Duration(hours: 1)),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      TaskFormSheet.show(context, task: prefilledTask);
                    },
                    icon: const Icon(LucideIcons.plus, size: 12),
                    label: Text(l10n.strings.cardScheduleHere),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
