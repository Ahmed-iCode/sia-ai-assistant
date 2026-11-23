import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/l10n/app_localizations.dart';
import 'package:app/core/l10n/app_strings.dart';
import 'package:app/core/l10n/locale_provider.dart';
import 'package:app/core/services/api_client.dart';
import 'package:app/core/services/storage_service.dart';
import 'package:app/features/ai_assistant/ai_assistant_provider.dart';
import 'package:app/features/auth/auth_provider.dart';
import 'package:app/features/auth/login_screen.dart';
import 'package:app/features/auth/register_screen.dart';

class _FakeFailingAuthNotifier extends AuthNotifier {
  final ApiException exceptionToThrow;

  _FakeFailingAuthNotifier(this.exceptionToThrow);

  @override
  Future<AuthState> build() async => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<bool> login(String email, String password) async {
    state = AsyncValue.data(
      AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: exceptionToThrow.message,
      ),
    );
    throw exceptionToThrow;
  }

  @override
  Future<bool> register(String name, String email, String password) async {
    state = AsyncValue.data(
      AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: exceptionToThrow.message,
      ),
    );
    throw exceptionToThrow;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.clear();
  });

  group('Sia Branding Tests', () {
    test('AppStrings contains Sia branding in Arabic and English', () {
      expect(AppStrings.en.appTitle, equals('Sia'));
      expect(AppStrings.ar.appTitle, equals('Sia'));
      expect(AppStrings.en.loginSubtitle, contains('Sia'));
      expect(AppStrings.ar.loginSubtitle, contains('Sia'));
      expect(AppStrings.ar.loginSubtitle, isNot(contains('سيا')));
      expect(AppStrings.ar.appTitle, isNot(contains('سيا')));
    });

    test('AiAssistantProvider initial welcome message introduces Sia', () {
      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith(() => _FixedLocaleNotifier(const Locale('ar'))),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(aiAssistantProvider);
      expect(state.messages, isNotEmpty);
      expect(state.messages.first.text, contains('Sia'));
      expect(state.messages.first.text, isNot(contains('سيا')));
    });
  });

  group('Auth Localized Error Feedback Tests', () {
    Widget buildTestApp({
      required Widget home,
      required Locale locale,
      required ApiException errorToThrow,
    }) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _FakeFailingAuthNotifier(errorToThrow)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          home: home,
        ),
      );
    }

    testWidgets('LoginScreen shows prominent inline error banner on 401 wrong credentials (Arabic)', (WidgetTester tester) async {
      const error401 = ApiException(
        statusCode: 401,
        message: 'Incorrect email or password',
      );

      await tester.pumpWidget(
        buildTestApp(
          home: const LoginScreen(),
          locale: const Locale('ar'),
          errorToThrow: error401,
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid format credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass123');
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify inline error banner is rendered with Arabic localized message
      expect(find.byKey(const Key('login_error_banner_text')), findsOneWidget);
      expect(
        find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'),
        findsOneWidget,
      );

      // Typing in email clears the banner
      await tester.enterText(find.byType(TextFormField).at(0), 'user2@example.com');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_error_banner_text')), findsNothing);
    });

    testWidgets('RegisterScreen shows prominent inline error banner on duplicate email (Arabic)', (WidgetTester tester) async {
      const error400 = ApiException(
        statusCode: 400,
        message: 'A user with this email already exists',
      );

      await tester.pumpWidget(
        buildTestApp(
          home: const RegisterScreen(),
          locale: const Locale('ar'),
          errorToThrow: error400,
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid fields
      await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed Samir');
      await tester.enterText(find.byType(TextFormField).at(1), 'existing@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Pass1234!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Pass1234!');
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify inline error banner is rendered with duplicate email message
      expect(find.byKey(const Key('register_error_banner_text')), findsOneWidget);
      expect(
        find.text('هذا الحساب مستخدم من قبل. جرّب تسجيل الدخول أو استخدم بريداً آخر.'),
        findsOneWidget,
      );
    });

    testWidgets('RegisterScreen validates password mismatch on client side', (WidgetTester tester) async {
      const error400 = ApiException(statusCode: 400, message: '');

      await tester.pumpWidget(
        buildTestApp(
          home: const RegisterScreen(),
          locale: const Locale('ar'),
          errorToThrow: error400,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed Samir');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'DifferentPassword');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
      expect(find.byKey(const Key('register_error_banner_text')), findsNothing);
    });
  });
}

class _FixedLocaleNotifier extends LocaleNotifier {
  final Locale _fixed;
  _FixedLocaleNotifier(this._fixed);

  @override
  Locale build() => _fixed;
}
