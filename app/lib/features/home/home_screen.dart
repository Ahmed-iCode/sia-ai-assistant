import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/responsive_layout.dart';
import '../tasks/tasks_view.dart';
import '../ai_assistant/ai_assistant_view.dart';
import '../settings/settings_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'home_provider.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/quick_voice_fab.dart';
import 'widgets/web_desktop_split_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout.builder(
      context: context,
      mobile: _buildMobileScaffold(context),
      desktop: const WebDesktopSplitView(),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentTab = ref.watch(homeTabProvider);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider).value;
    final isAuthenticated = authState?.isAuthenticated ?? false;
    final currentUser = authState?.user;
    final avatarLetter = currentUser?.name.isNotEmpty == true
        ? currentUser!.name[0].toUpperCase()
        : (l10n.isArabic ? 'أ' : 'A');

    final screens = const [
      TasksView(),
      AiAssistantView(),
      SettingsScreen(),
    ];

    return Scaffold(
      appBar: currentTab == 1 // AI Assistant has its own rich custom app bar
          ? null
          : AppBar(
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.asset(
                        'assets/images/sia_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.strings.appTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                // Language switch button
                IconButton(
                  tooltip: l10n.strings.languageLabel,
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      currentLocale.languageCode == 'ar' ? 'EN' : 'عربي',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  onPressed: () {
                    ref.read(localeProvider.notifier).toggleLocale();
                  },
                ),

                // Theme Toggle
                IconButton(
                  tooltip: l10n.strings.themeLabel,
                  icon: Icon(
                    currentThemeMode == ThemeMode.dark ? LucideIcons.sun : LucideIcons.moon,
                    size: 18,
                  ),
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).toggleTheme();
                  },
                ),

                // User Avatar Profile button (or login icon if unauthenticated)
                if (isAuthenticated)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      ref.read(homeTabProvider.notifier).setTab(2);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
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
                          avatarLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: l10n.strings.signInButton,
                    icon: const Icon(LucideIcons.user, size: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                const SizedBox(width: 4),
              ],
            ),
      body: IndexedStack(
        index: currentTab,
        children: screens,
      ),
      floatingActionButton: currentTab == 0 ? const QuickVoiceFab() : null,
      bottomNavigationBar: MobileBottomNav(
        currentIndex: currentTab,
        onTabSelected: (index) {
          ref.read(homeTabProvider.notifier).setTab(index);
        },
      ),
    );
  }
}
