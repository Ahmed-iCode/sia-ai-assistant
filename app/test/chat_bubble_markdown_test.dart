import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app/core/l10n/app_localizations.dart';
import 'package:app/core/models/chat_message_model.dart';
import 'package:app/features/ai_assistant/widgets/chat_bubble.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  Widget createTestWidget(ChatMessageModel message) {
    return MaterialApp(
      locale: const Locale('ar'),
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
      home: Scaffold(
        body: ChatBubble(
          message: message,
          onUndoTask: () {},
          onConfirmDelete: () {},
          onCancelDelete: () {},
        ),
      ),
    );
  }

  testWidgets('ChatBubble renders MarkdownBody for assistant messages', (WidgetTester tester) async {
    final assistantMessage = ChatMessageModel(
      id: 'msg-1',
      text: 'مرحباً بك! أنا **Sia** من تطوير فريق **T4S**.',
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(createTestWidget(assistantMessage));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    final markdownWidget = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdownWidget.data, contains('**Sia**'));
    expect(markdownWidget.data, contains('**T4S**'));
  });

  testWidgets('ChatBubble renders plain Text for user messages', (WidgetTester tester) async {
    final userMessage = ChatMessageModel(
      id: 'msg-2',
      text: 'Add meeting tomorrow at 10am',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(createTestWidget(userMessage));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('Add meeting tomorrow at 10am'), findsOneWidget);
  });
}
