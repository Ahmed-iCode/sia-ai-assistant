import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable model representing the release manifest published on GitHub.
class AppUpdateInfo {
  final String versionName;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  const AppUpdateInfo({
    required this.versionName,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final vName = json['version_name']?.toString() ??
        json['versionName']?.toString() ??
        '1.0.0';
    final rawBuild = json['build_number'] ?? json['buildNumber'] ?? 0;
    final bNum = rawBuild is int
        ? rawBuild
        : int.tryParse(rawBuild.toString()) ?? 0;
    final dUrl = json['download_url']?.toString() ??
        json['downloadUrl']?.toString() ??
        'https://github.com/Ahmed-iCode/sia-ai-assistant/releases/latest/download/Sia.apk';
    final notes = json['release_notes']?.toString() ??
        json['releaseNotes']?.toString() ??
        'تحسينات جديدة في الأداء وإصلاحات لتطبيق Sia.';
    final rawPub = json['published_at'] ?? json['publishedAt'];
    DateTime pubDate;
    if (rawPub is String) {
      pubDate = DateTime.tryParse(rawPub) ?? DateTime.now();
    } else {
      pubDate = DateTime.now();
    }

    return AppUpdateInfo(
      versionName: vName,
      buildNumber: bNum,
      downloadUrl: dUrl,
      releaseNotes: notes,
      publishedAt: pubDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_name': versionName,
      'build_number': buildNumber,
      'download_url': downloadUrl,
      'release_notes': releaseNotes,
      'published_at': publishedAt.toUtc().toIso8601String(),
    };
  }

  /// Pure static comparison helper to check if a remote build is newer.
  static bool isNewerVersion({
    required int localBuildNumber,
    required int remoteBuildNumber,
  }) =>
      remoteBuildNumber > localBuildNumber;
}

/// Service that checks for GitHub release updates and manages notification/dismissal states.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String manifestUrl =
      'https://github.com/Ahmed-iCode/sia-ai-assistant/releases/latest/download/version.json';
  static const String keyDismissedUpdateBuild = 'dismissed_update_build';
  static const String keyLastNotifiedUpdateBuild = 'last_notified_update_build';

  /// Returns true only on supported mobile platforms (Android) and outside headless unit tests.
  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    } catch (_) {}
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Fetches the latest release `version.json` manifest with cache-busting.
  Future<AppUpdateInfo?> fetchLatestReleaseManifest({Dio? customDio}) async {
    if (!isSupportedPlatform && customDio == null) return null;

    final client = customDio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Accept': 'application/json'},
          ),
        );

    final url = '$manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    try {
      final response = await client.get<dynamic>(url);
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map<String, dynamic>) {
          return AppUpdateInfo.fromJson(response.data as Map<String, dynamic>);
        } else if (response.data is String) {
          final decoded = jsonDecode(response.data as String);
          if (decoded is Map<String, dynamic>) {
            return AppUpdateInfo.fromJson(decoded);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AppUpdateService] Error fetching manifest: $e');
      return null;
    }
  }

  /// Returns local build number safely from platform package info.
  Future<int> getLocalBuildNumber() async {
    if (kIsWeb) return 0;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return 0;
      final pkg = await PackageInfo.fromPlatform();
      return int.tryParse(pkg.buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Returns human-readable version string for UI display.
  Future<String> getAppVersionDisplay() async {
    if (kIsWeb) return 'v1.0.0 (Web)';
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return 'v1.0.0';
      }
      final pkg = await PackageInfo.fromPlatform();
      return 'v${pkg.version} (${pkg.buildNumber})';
    } catch (_) {
      return 'v1.0.0';
    }
  }

  /// Checks if a newer version is available.
  /// When [isManual] is false, previously dismissed builds are suppressed.
  Future<AppUpdateInfo?> checkForUpdate({
    bool isManual = false,
    int? overrideLocalBuild,
    Dio? customDio,
  }) async {
    if (!isSupportedPlatform && customDio == null) return null;

    final localBuild = overrideLocalBuild ?? await getLocalBuildNumber();
    final manifest = await fetchLatestReleaseManifest(customDio: customDio);
    if (manifest == null) return null;

    if (!AppUpdateInfo.isNewerVersion(
      localBuildNumber: localBuild,
      remoteBuildNumber: manifest.buildNumber,
    )) {
      return null;
    }

    if (!isManual) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final dismissedBuild = prefs.getInt(keyDismissedUpdateBuild);
        if (dismissedBuild == manifest.buildNumber) {
          debugPrint(
            '[AppUpdateService] Update to build ${manifest.buildNumber} was previously dismissed by user.',
          );
          return null;
        }
      } catch (e) {
        debugPrint('[AppUpdateService] Error checking dismissal: $e');
      }
    }

    return manifest;
  }

  /// Marks a specific build number as dismissed by the user (suppresses auto popups).
  Future<void> dismissUpdate(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyDismissedUpdateBuild, buildNumber);
    } catch (e) {
      debugPrint('[AppUpdateService] Error saving dismissal: $e');
    }
  }

  /// Records that a notification was sent for this build number (prevents spamming).
  Future<void> markUpdateNotified(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyLastNotifiedUpdateBuild, buildNumber);
    } catch (e) {
      debugPrint('[AppUpdateService] Error saving notification flag: $e');
    }
  }

  /// Checks if a notification was already delivered for this build number.
  Future<bool> wasUpdateNotified(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(keyLastNotifiedUpdateBuild) == buildNumber;
    } catch (e) {
      return false;
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService.instance;
});
