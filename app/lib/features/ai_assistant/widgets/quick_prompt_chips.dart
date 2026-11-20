import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

class QuickPromptChips extends StatelessWidget {
  final Function(String) onSelectPrompt;

  const QuickPromptChips({super.key, required this.onSelectPrompt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final prompts = [
      (l10n.strings.quickPrompt1, LucideIcons.calendar),
      (l10n.strings.quickPrompt2, LucideIcons.sparkles),
      (l10n.strings.quickPrompt3, LucideIcons.plusCircle),
      (l10n.strings.quickPrompt4, LucideIcons.alertTriangle),
      (l10n.strings.quickPrompt5, LucideIcons.bell),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            l10n.strings.quickPromptsLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: prompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return ActionChip(
                backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                avatar: Icon(prompt.$2, size: 13, color: AppColors.primary),
                label: Text(prompt.$1),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                onPressed: () => onSelectPrompt(prompt.$1),
              );
            },
          ),
        ),
      ],
    );
  }
}
