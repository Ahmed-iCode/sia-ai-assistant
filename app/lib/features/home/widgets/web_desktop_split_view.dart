import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../tasks/tasks_view.dart';
import '../../ai_assistant/ai_assistant_view.dart';
import '../../settings/settings_screen.dart';
import '../../auth/auth_provider.dart';
import '../../auth/login_screen.dart';
import '../home_provider.dart';

class WebDesktopSplitView extends ConsumerWidget {
  const WebDesktopSplitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentTab = ref.watch(homeTabProvider);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider).value;
    final isAuthenticated = authState?.isAuthenticated ?? false;
    final currentUser = authState?.user;
    final userName = currentUser?.name.isNotEmpty == true ? currentUser!.name : 'User';
    final userInitial = userName[0].toUpperCase();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Image.asset(
                  'assets/images/sia_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.strings.appTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 24),

            // Desktop Tab navigation pills
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  _buildNavPill(
                    context,
                    ref,
                    title: l10n.strings.navSchedule,
                    icon: LucideIcons.calendar,
                    index: 0,
                    currentIndex: currentTab,
                    isDark: isDark,
                  ),
                  _buildNavPill(
                    context,
                    ref,
                    title: l10n.strings.navSettings,
                    icon: LucideIcons.settings,
                    index: 2,
                    currentIndex: currentTab,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Language Switcher (AR / EN)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangPill(ref, 'ar', 'عربي', currentLocale.languageCode == 'ar', isDark),
                _buildLangPill(ref, 'en', 'EN', currentLocale.languageCode == 'en', isDark),
              ],
            ),
          ),

          // Theme Toggle (Dark / Light)
          IconButton(
            tooltip: l10n.strings.themeLabel,
            icon: Icon(
              currentThemeMode == ThemeMode.dark ? LucideIcons.sun : LucideIcons.moon,
              size: 20,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),

          // User Profile Pill (Authenticated) vs Sign In Button (Unauthenticated)
          if (isAuthenticated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: PopupMenuButton<String>(
                tooltip: userName,
                offset: const Offset(0, 42),
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                onSelected: (val) async {
                  if (val == 'sign_out') {
                    await ref.read(authProvider.notifier).logout();
                  } else if (val == 'settings') {
                    ref.read(homeTabProvider.notifier).setTab(2);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (currentUser?.email != null)
                          Text(
                            currentUser!.email,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(LucideIcons.settings, size: 16),
                        const SizedBox(width: 10),
                        Text(l10n.strings.navSettings),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sign_out',
                    child: Row(
                      children: [
                        const Icon(LucideIcons.logOut, size: 16, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text(
                          l10n.strings.signOutButton,
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            userInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          userName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(LucideIcons.user, size: 16),
                label: Text(l10n.strings.signInButton),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Side (Tasks / Schedule or Settings)
          Expanded(
            flex: 6,
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              child: currentTab == 2 ? const SettingsScreen() : const TasksView(),
            ),
          ),

          // Vertical Divider
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),

          // Right Side AI Assistant Panel (Flex 4)
          Expanded(
            flex: 4,
            child: Container(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: const AiAssistantView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required int index,
    required int currentIndex,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => ref.read(homeTabProvider.notifier).setTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangPill(
    WidgetRef ref,
    String code,
    String label,
    bool isSelected,
    bool isDark,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        ref.read(localeProvider.notifier).setLocale(Locale(code));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
