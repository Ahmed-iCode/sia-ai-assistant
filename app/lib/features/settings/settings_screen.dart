import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'settings_provider.dart';
import 'widgets/settings_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settings = ref.watch(settingsProvider);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider).value;
    final currentUser = authState?.user;

    final avatarLetter = currentUser?.name.isNotEmpty == true
        ? currentUser!.name[0].toUpperCase()
        : (l10n.isArabic ? 'أ' : 'A');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.strings.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          // User Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
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
            child: Row(
              children: [
                // Avatar with initials
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(isDark ? 80 : 40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name and Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.name ?? l10n.strings.userProfileName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentUser?.email ?? l10n.strings.userProfileEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withAlpha(100)),
                  ),
                  child: Text(
                    'Active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section 1: Appearance & Language
          SettingsSection(
            title: l10n.strings.sectionPreferences,
            children: [
              // Language Switcher
              ListTile(
                leading: const Icon(LucideIcons.languages, size: 20),
                title: Text(l10n.strings.languageLabel),
                trailing: DropdownButton<String>(
                  value: currentLocale.languageCode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 'ar', child: Text(l10n.strings.languageArabic)),
                    DropdownMenuItem(value: 'en', child: Text(l10n.strings.languageEnglish)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(localeProvider.notifier).setLocale(Locale(val));
                      ref.read(settingsProvider.notifier).updateLanguage(val);
                    }
                  },
                ),
              ),

              // Theme Mode Selector
              ListTile(
                leading: const Icon(LucideIcons.palette, size: 20),
                title: Text(l10n.strings.themeLabel),
                trailing: DropdownButton<ThemeMode>(
                  value: currentThemeMode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.strings.themeDark)),
                    DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.strings.themeLight)),
                    DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.strings.themeSystem)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                      final modeStr = val == ThemeMode.dark
                          ? 'dark'
                          : (val == ThemeMode.light ? 'light' : 'system');
                      ref.read(settingsProvider.notifier).updateThemeMode(modeStr);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Scheduling Rules & Defaults
          SettingsSection(
            title: l10n.strings.sectionScheduleRules,
            children: [
              // Working Hours
              ListTile(
                leading: const Icon(LucideIcons.clock, size: 20),
                title: Text(l10n.strings.workingHoursLabel),
                subtitle: Text(
                  l10n.strings.workingHoursDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '${settings.workingHoursStart} - ${settings.workingHoursEnd}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Default Reminder Offset
              ListTile(
                leading: const Icon(LucideIcons.bell, size: 20),
                title: Text(l10n.strings.defaultReminderLabel),
                trailing: DropdownButton<int>(
                  value: settings.defaultReminderOffsetMinutes,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(settingsProvider.notifier).updateReminderOffset(val);
                    }
                  },
                ),
              ),

              // Timezone
              ListTile(
                leading: const Icon(LucideIcons.globe, size: 20, color: AppColors.info),
                title: Text(l10n.strings.timezoneLabel),
                trailing: Text(
                  settings.timezone,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),

              // Notifications Toggle
              SwitchListTile(
                secondary: const Icon(LucideIcons.bellRing, size: 20),
                title: Text(l10n.strings.notificationsLabel),
                value: settings.notificationsEnabled,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).toggleNotifications(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3: Account & Session
          SettingsSection(
            title: l10n.strings.sectionAccount,
            children: [
              // Sign Out
              ListTile(
                leading: const Icon(LucideIcons.logOut, size: 20, color: AppColors.error),
                title: Text(
                  l10n.strings.signOutButton,
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
