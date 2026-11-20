import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized safe key-value persistence service.
/// Uses [SharedPreferences] with an automatic in-memory fallback to guarantee
/// that platform channel or web plugin initialization issues never throw
/// unhandled [MissingPluginException].
class StorageService {
  static final Map<String, String> _memoryStore = {};
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  /// Pre-initialize preferences (e.g. inside `main()` after binding initialization).
  static Future<void> init() async {
    if (_initialized && _prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (e) {
      debugPrint('[StorageService] SharedPreferences fallback to memory store: $e');
    }
  }

  /// Retrieve a stored String by key.
  static Future<String?> getString(String key) async {
    try {
      if (_prefs == null && !_initialized) {
        await init();
      }
      if (_prefs != null) {
        final val = _prefs!.getString(key);
        if (val != null) return val;
      }
    } catch (e) {
      debugPrint('[StorageService] getString error for "$key": $e');
    }
    return _memoryStore[key];
  }

  /// Store a String value by key.
  static Future<bool> setString(String key, String value) async {
    _memoryStore[key] = value;
    try {
      if (_prefs == null && !_initialized) {
        await init();
      }
      if (_prefs != null) {
        return await _prefs!.setString(key, value);
      }
    } catch (e) {
      debugPrint('[StorageService] setString error for "$key": $e');
    }
    return true;
  }

  /// Remove a stored value by key.
  static Future<bool> remove(String key) async {
    _memoryStore.remove(key);
    try {
      if (_prefs == null && !_initialized) {
        await init();
      }
      if (_prefs != null) {
        return await _prefs!.remove(key);
      }
    } catch (e) {
      debugPrint('[StorageService] remove error for "$key": $e');
    }
    return true;
  }

  /// Clear all stored values.
  static Future<bool> clear() async {
    _memoryStore.clear();
    try {
      if (_prefs == null && !_initialized) {
        await init();
      }
      if (_prefs != null) {
        return await _prefs!.clear();
      }
    } catch (e) {
      debugPrint('[StorageService] clear error: $e');
    }
    return true;
  }
}
