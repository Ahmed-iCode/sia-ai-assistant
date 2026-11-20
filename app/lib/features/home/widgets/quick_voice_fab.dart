import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../home_provider.dart';

class QuickVoiceFab extends ConsumerWidget {
  const QuickVoiceFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(isDark ? 120 : 80),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        tooltip: l10n.strings.micTapToRecord,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
        onPressed: () {
          // Switch to AI Assistant tab
          ref.read(homeTabProvider.notifier).setTab(1);
        },
        child: const Icon(LucideIcons.mic, size: 24),
      ),
    );
  }
}
