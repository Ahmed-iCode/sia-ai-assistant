import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_settings_model.dart';
import '../../core/services/rest_task_repository.dart';
import '../auth/auth_provider.dart';
import '../tasks/tasks_provider.dart';

class SettingsNotifier extends Notifier<UserSettingsModel> {
  @override
  UserSettingsModel build() {
    ref.listen(authProvider, (prev, next) {
      if (next.value?.isAuthenticated == true && prev?.value?.isAuthenticated != true) {
        _fetchRemoteSettings();
      }
    });
    return const UserSettingsModel();
  }

  Future<void> _fetchRemoteSettings() async {
    try {
      final authState = ref.read(authProvider).value;
      if (authState == null || !authState.isAuthenticated) return;
      final repo = ref.read(restTaskRepositoryProvider);
      final remote = await repo.getSettings();
      state = remote;
    } catch (_) {}
  }

  Future<void> _syncToRemote(UserSettingsModel newSettings) async {
    state = newSettings;
    try {
      final authState = ref.read(authProvider).value;
      if (authState == null || !authState.isAuthenticated) return;
      final repo = ref.read(restTaskRepositoryProvider);
      await repo.updateSettings(newSettings);
    } catch (_) {}
  }

  void updateLanguage(String lang) {
    _syncToRemote(state.copyWith(language: lang));
  }

  void updateThemeMode(String mode) {
    _syncToRemote(state.copyWith(themeMode: mode));
  }

  void updateWorkingHours({String? start, String? end}) {
    _syncToRemote(state.copyWith(
      workingHoursStart: start ?? state.workingHoursStart,
      workingHoursEnd: end ?? state.workingHoursEnd,
    ));
  }

  void updateReminderOffset(int minutes) {
    _syncToRemote(state.copyWith(defaultReminderOffsetMinutes: minutes));
  }

  void updateTimezone(String tz) {
    _syncToRemote(state.copyWith(timezone: tz));
  }

  void toggleNotifications(bool val) {
    _syncToRemote(state.copyWith(notificationsEnabled: val));
  }

  void toggleSound(bool val) {
    _syncToRemote(state.copyWith(soundEnabled: val));
  }

  void toggleVibration(bool val) {
    _syncToRemote(state.copyWith(vibrationEnabled: val));
  }

  Future<void> resetDemoData() async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.resetDemoData();
    ref.read(tasksProvider.notifier).refresh();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, UserSettingsModel>(
  SettingsNotifier.new,
);
