import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Listen for 401 session expiration from ApiClient interceptor
    ref.listen(authExpiredSignalProvider, (prev, next) {
      if (prev != null && next > prev) {
        logout();
      }
    });

    final authService = ref.read(authServiceProvider);
    final savedToken = await authService.getSavedToken();
    if (savedToken == null || savedToken.isEmpty) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    try {
      final user = await authService.getMe();
      return AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Token expired or invalid
      await authService.logout();
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    final current = state.value ?? const AuthState(status: AuthStatus.unauthenticated);
    state = AsyncValue.data(current.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.login(email: email, password: password);
      state = AsyncValue.data(
        AuthState(status: AuthStatus.authenticated, user: user),
      );
      return true;
    } on ApiException catch (e) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
      rethrow;
    } catch (e) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    final current = state.value ?? const AuthState(status: AuthStatus.unauthenticated);
    state = AsyncValue.data(current.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.register(name: name, email: email, password: password);
      state = AsyncValue.data(
        AuthState(status: AuthStatus.authenticated, user: user),
      );
      return true;
    } on ApiException catch (e) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
      rethrow;
    } catch (e) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  void clearError() {
    if (state.value?.errorMessage != null) {
      state = AsyncValue.data(
        state.value!.copyWith(errorMessage: null),
      );
    }
  }

  Future<bool> loginDemo() async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.loginDemo();
      state = AsyncValue.data(
        AuthState(status: AuthStatus.authenticated, user: user),
      );
      return true;
    } catch (e) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString().replaceFirst('ApiException: ', ''),
        ),
      );
      return false;
    }
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AsyncValue.data(
      AuthState(status: AuthStatus.unauthenticated),
    );
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
