import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user_data';

  Future<String?> getSavedToken() async {
    try {
      return await StorageService.getString(tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> getSavedUser() async {
    try {
      final userJson = await StorageService.getString(userKey);
      if (userJson != null) {
        return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  String _extractErrorDetail(dynamic data, String fallback) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first.containsKey('msg')) {
          return first['msg'].toString();
        }
        return detail.map((e) => e.toString()).join(', ');
      }
    }
    return fallback;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      final token = response.data['accessToken'] as String;
      await StorageService.setString(tokenKey, token);

      final user = await getMe();
      await StorageService.setString(userKey, jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      final msg = _extractErrorDetail(e.response?.data, e.message ?? 'Registration failed');
      throw ApiException(
        message: msg,
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final token = response.data['accessToken'] as String;
      await StorageService.setString(tokenKey, token);

      final user = await getMe();
      await StorageService.setString(userKey, jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      final msg = _extractErrorDetail(e.response?.data, e.message ?? 'Login failed');
      throw ApiException(
        message: msg,
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<UserModel> loginDemo() async {
    const demoEmail = 'demo@smarttask.ai';
    const demoPass = 'Demo1234!';
    const demoName = 'Demo User';

    try {
      return await login(email: demoEmail, password: demoPass);
    } catch (_) {
      // If login fails (user does not exist yet), auto-register demo user
      try {
        return await register(name: demoName, email: demoEmail, password: demoPass);
      } catch (e) {
        // Retry login if race condition
        return await login(email: demoEmail, password: demoPass);
      }
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['detail'] as String? ?? 'Failed to get profile')
          : 'Failed to get profile';
      throw ApiException(message: msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> logout() async {
    try {
      await StorageService.remove(tokenKey);
      await StorageService.remove(userKey);
    } catch (_) {}
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AuthService(dio);
});
