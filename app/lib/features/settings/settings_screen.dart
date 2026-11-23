import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_update_dialog.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../tasks/tasks_provider.dart';
import 'settings_provider.dart';
import 'widgets/settings_section.dart';

final pendingNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return await ref.watch(notificationServiceProvider).getPendingNotificationCount();
});

final canScheduleExactAlarmsProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return await ref.watch(notificationServiceProvider).canScheduleExactAlarms();
});

final appVersionDisplayProvider =
    FutureProvider.autoDispose<String>((ref) async {
  return await ref.watch(appUpdateServiceProvider).getAppVersionDisplay();
});

final updateCheckLoadingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

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
                onChanged: (val) async {
                  ref.read(settingsProvider.notifier).toggleNotifications(val);
                  if (val && !kIsWeb) {
                    await ref.read(notificationServiceProvider).requestPermissions();
                    final tasks = ref.read(tasksProvider).value ?? [];
                    await ref.read(notificationServiceProvider).syncAllTaskReminders(tasks);
                  }
                },
              ),
            ],
          ),

          // Diagnostic Section: Mobile Notifications & Reminders
          if (!kIsWeb) ...[
            const SizedBox(height: 16),
            SettingsSection(
              title: l10n.isArabic
                  ? 'إشعارات وتذكيرات الموبايل'
                  : 'Mobile Notification Diagnostics',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.shieldCheck,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.isArabic
                                  ? 'فحص واختبار التنبيهات المجدولة'
                                  : 'Diagnose & Test Scheduled Alarms',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.isArabic
                            ? 'اختبر وصول التنبيهات على جهازك للتأكد من عمل منبه النظام والإشعارات في الخلفية.'
                            : 'Test notification delivery on your device to ensure system alarms work while the app is closed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Exact Alarm Permission Warning Banner (Android 12+ / MIUI)
                      Consumer(
                        builder: (context, ref, _) {
                          final canExactAsync =
                              ref.watch(canScheduleExactAlarmsProvider);
                          return canExactAsync.when(
                            data: (canExact) {
                              if (canExact) return const SizedBox.shrink();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withAlpha(isDark ? 40 : 25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.warning
                                        .withAlpha(isDark ? 120 : 100),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.alertTriangle,
                                          size: 18,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.isArabic
                                                ? 'تنبيه: صلاحية المنبه الدقيق غير مفعّلة'
                                                : 'Exact Alarm Permission Required',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.isArabic
                                          ? 'على أجهزة Android الحديثة وMIUI، يحتاج Sia لتفعيل صلاحية المنبه لضمان رنين التنبيهات في موعدها الدقيق في الخلفية.'
                                          : 'On Android 12+ and MIUI, Sia requires exact alarm permission to deliver reminders precisely on time.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(height: 1.4),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.warning,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        icon: const Icon(LucideIcons.settings,
                                            size: 16),
                                        label: Text(
                                          l10n.isArabic
                                              ? 'تفعيل صلاحية المنبه الدقيق'
                                              : 'Enable Exact Alarm Permission',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  notificationServiceProvider)
                                              .requestExactAlarmsPermission();
                                          ref.invalidate(
                                              canScheduleExactAlarmsProvider);
                                          ref.invalidate(
                                              pendingNotificationsCountProvider);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (err, stack) => const SizedBox.shrink(),
                          );
                        },
                      ),

                      Row(
                        children: [
                          // Button 1: Test Now
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(LucideIcons.bell, size: 16),
                              label: Text(
                                l10n.isArabic ? 'إشعار فوري' : 'Test Now',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final success = await ref
                                    .read(notificationServiceProvider)
                                    .showImmediateTestNotification();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? (l10n.isArabic
                                                ? 'تم إرسال إشعار تجريبي فوري بنجاح! تفقد شريط الإشعارات.'
                                                : 'Immediate test notification sent! Check your notification bar.')
                                            : (l10n.isArabic
                                                ? 'تعذر إرسال الإشعار، يُرجى التأكد من صلاحيات الإشعارات.'
                                                : 'Could not send notification. Please check notification permissions.'),
                                      ),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Button 2: Test in 10s
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(LucideIcons.timer, size: 16),
                              label: Text(
                                l10n.isArabic ? 'تذكير بعد 10ث' : 'Test in 10s',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final canExact = await ref
                                    .read(notificationServiceProvider)
                                    .canScheduleExactAlarms();
                                final success = await ref
                                    .read(notificationServiceProvider)
                                    .scheduleDelayed10sTestNotification();
                                ref.invalidate(pendingNotificationsCountProvider);
                                ref.invalidate(canScheduleExactAlarmsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? (canExact
                                                ? (l10n.isArabic
                                                    ? '⏰ تم جدولة التنبيه الدقيق بعد 10 ثواني! اقفل الشاشة للتأكد من رنينه.'
                                                    : '⏰ Exact alarm scheduled for 10 seconds! Lock your screen to verify.')
                                                : (l10n.isArabic
                                                    ? '⏰ تم جدولة التنبيه (بالوضع التقريبي) بعد 10 ثواني! قم بتفعيل صلاحية المنبه الدقيق لدقة 100%.'
                                                    : '⏰ Alarm scheduled (inexact mode) for 10 seconds! Grant exact alarm permission for 100% accuracy.'))
                                            : (l10n.isArabic
                                                ? 'تعذر جدولة التنبيه، يُرجى التأكد من صلاحيات المنبه والإشعارات.'
                                                : 'Could not schedule alarm. Please check alarm and notification permissions.'),
                                      ),
                                      duration: const Duration(seconds: 6),
                                      backgroundColor: success
                                          ? AppColors.primary
                                          : AppColors.error,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Scheduled Alarms Count on Device
                      Consumer(
                        builder: (context, ref, _) {
                          final countAsync =
                              ref.watch(pendingNotificationsCountProvider);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkBackground
                                  : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alarmClock,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: countAsync.when(
                                    data: (count) => Text(
                                      l10n.isArabic
                                          ? 'الإشعارات المجدولة حالياً على الجهاز: $count'
                                          : 'Scheduled Alarms on Device: $count',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    loading: () => Text(
                                      l10n.isArabic
                                          ? 'جاري فحص الإشعارات...'
                                          : 'Checking alarms...',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                    error: (err, stack) => Text(
                                      l10n.isArabic
                                          ? 'تعذر قراءة الإشعارات المجدولة'
                                          : 'Unavailable',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: l10n.isArabic ? 'تحديث' : 'Refresh',
                                  onPressed: () {
                                    ref.invalidate(
                                      pendingNotificationsCountProvider,
                                    );
                                    ref.invalidate(
                                      canScheduleExactAlarmsProvider,
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Section: About & Updates
          SettingsSection(
            title: l10n.isArabic ? 'حول التطبيق والتحديثات' : 'About & Updates',
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final versionAsync = ref.watch(appVersionDisplayProvider);
                  final isChecking = ref.watch(updateCheckLoadingProvider);

                  return ListTile(
                    leading: const Icon(LucideIcons.info, size: 20, color: AppColors.primary),
                    title: const Text(
                      'Sia',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: versionAsync.when(
                      data: (version) => Text(
                        '${l10n.isArabic ? 'الإصدار المثبت: ' : 'Installed: '}$version',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      loading: () => Text(
                        l10n.isArabic ? 'جاري التحميل...' : 'Loading...',
                        style: theme.textTheme.bodySmall,
                      ),
                      error: (err, stack) => const Text('v1.0.0'),
                    ),
                    trailing: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(LucideIcons.refreshCw, size: 14),
                            label: Text(
                              l10n.isArabic ? 'فحص التحديثات' : 'Check for Updates',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () async {
                              ref.read(updateCheckLoadingProvider.notifier).state = true;
                              try {
                                final updateInfo = await ref
                                    .read(appUpdateServiceProvider)
                                    .checkForUpdate(isManual: true);

                                if (context.mounted) {
                                  if (updateInfo != null) {
                                    await AppUpdateDialog.show(context, updateInfo);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.isArabic
                                              ? '🎉 أنت تستخدم أحدث إصدار من Sia بالفعل!'
                                              : '🎉 You are already using the latest version of Sia!',
                                        ),
                                        duration: const Duration(seconds: 4),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint('[SettingsScreen] Update check failed: $e');
                              } finally {
                                ref.read(updateCheckLoadingProvider.notifier).state = false;
                              }
                            },
                          ),
                  );
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
