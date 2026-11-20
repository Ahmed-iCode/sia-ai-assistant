import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

class ApiConfigNotifier extends StateNotifier<String> {
  static const String _prefsKey = 'api_base_url_override';
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  ApiConfigNotifier() : super(defaultBaseUrl) {
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    try {
      final saved = await StorageService.getString(_prefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        state = saved.trim();
      }
    } catch (_) {
      // Keep default on web / error
    }
  }

  Future<void> setBaseUrl(String newUrl) async {
    final cleaned = newUrl.trim();
    if (cleaned.isEmpty) return;
    state = cleaned;
    await StorageService.setString(_prefsKey, cleaned);
  }

  Future<void> resetToDefault() async {
    state = defaultBaseUrl;
    await StorageService.remove(_prefsKey);
  }
}

final apiConfigProvider = StateNotifierProvider<ApiConfigNotifier, String>((ref) {
  return ApiConfigNotifier();
});
