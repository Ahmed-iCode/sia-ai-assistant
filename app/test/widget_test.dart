import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/main.dart';
import 'package:app/core/models/user_model.dart';
import 'package:app/core/services/api_client.dart';
import 'package:app/core/services/mock_task_repository.dart';
import 'package:app/core/services/storage_service.dart';
import 'package:app/features/auth/auth_provider.dart';
import 'package:app/features/auth/login_screen.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/features/tasks/tasks_provider.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    String jsonResponse = '{}';
    if (path.contains('/tasks') || path.contains('/history')) {
      jsonResponse = '[]';
    }
    return ResponseBody.fromString(
      jsonResponse,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio fakeDio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.clear();
    fakeDio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))..httpClientAdapter = _MockHttpAdapter();
  });

  testWidgets('AiTaskAssistantApp renders LoginScreen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeDio),
          taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
        ],
        child: const AiTaskAssistantApp(),
      ),
    );

    // Initial pump & settle auth check
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('AiTaskAssistantApp renders HomeScreen when authenticated', (WidgetTester tester) async {
    final fakeUser = UserModel(
      id: 'test-user',
      name: 'Test User',
      email: 'test@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeDio),
          authProvider.overrideWith(
            () => _FakeAuthNotifier(AuthState(
              status: AuthStatus.authenticated,
              user: fakeUser,
            )),
          ),
          taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
        ],
        child: const AiTaskAssistantApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  test('Unauthenticated user gets empty tasks list without throwing 401', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeDio),
        authProvider.overrideWith(
          () => _FakeAuthNotifier(const AuthState(
            status: AuthStatus.unauthenticated,
          )),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tasks = await container.read(tasksProvider.future);
    expect(tasks, isEmpty);
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  Future<AuthState> build() async => _initial;
}
