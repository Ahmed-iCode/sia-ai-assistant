import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/models/chat_message_model.dart';
import '../../core/models/free_slot_model.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/rest_task_repository.dart';
import '../../core/services/notification_service.dart';
import '../auth/auth_provider.dart';
import '../tasks/tasks_provider.dart';

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

class AiAssistantState {
  final List<ChatMessageModel> messages;
  final bool isThinking;

  const AiAssistantState({
    this.messages = const [],
    this.isThinking = false,
  });

  AiAssistantState copyWith({
    List<ChatMessageModel>? messages,
    bool? isThinking,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}

class AiAssistantNotifier extends Notifier<AiAssistantState> {
  final _uuid = const Uuid();

  @override
  AiAssistantState build() {
    final currentLocale = ref.watch(localeProvider).languageCode;
    final isArabic = currentLocale == 'ar';
    final user = ref.watch(authProvider).value?.user;
    final userName = user?.name.trim();
    final greetingNameAr = (userName != null && userName.isNotEmpty) ? ' يا $userName' : '';
    final greetingNameEn = (userName != null && userName.isNotEmpty) ? ', $userName' : '';

    final welcomeMessage = ChatMessageModel(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      text: isArabic
          ? 'أهلاً بك$greetingNameAr! أنا سيا (Sia)، مساعدك الذكي لتنظيم الوقت والمهام. يمكنك سؤالي: "عندي تاسكات إيه النهاردة؟" أو "أنا فاضي إمتى؟" أو تسجيل طلبك صوتياً.'
          : 'Welcome$greetingNameEn! I am Sia, your intelligent AI Task & Schedule Assistant. Ask me "What tasks do I have today?", "When am I free?", or use your voice to schedule.',
      timestamp: DateTime.now(),
    );

    // Listen for auth state transitions to authenticated to load history
    ref.listen(authProvider, (prev, next) {
      if (next.value?.isAuthenticated == true && prev?.value?.isAuthenticated != true) {
        _loadHistory();
      }
    });

    return AiAssistantState(messages: [welcomeMessage]);
  }

  Future<void> _loadHistory() async {
    try {
      final authState = ref.read(authProvider).value;
      if (authState == null || !authState.isAuthenticated) return;
      final repo = ref.read(restTaskRepositoryProvider);
      final history = await repo.getChatHistory();
      if (history.isNotEmpty) {
        state = state.copyWith(messages: history);
      }
    } catch (_) {}
  }

  Future<void> sendMessage(
    String text, {
    bool isVoice = false,
    int? durationSeconds,
  }) async {
    final currentLocale = ref.read(localeProvider).languageCode;
    final isArabic = currentLocale == 'ar';

    final userMsg = ChatMessageModel(
      id: _uuid.v4(),
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
      isVoice: isVoice,
      audioDurationSeconds: durationSeconds,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    final authState = ref.read(authProvider).value;
    if (authState == null || !authState.isAuthenticated) {
      final errText = isArabic
          ? 'يُرجى تسجيل الدخول أولاً لتتمكن من التحدث مع المساعد الذكي.'
          : 'Please sign in first to interact with the AI assistant.';
      final errMessage = ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: errText,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errMessage],
        isThinking: false,
      );
      return;
    }

    try {
      final repo = ref.read(restTaskRepositoryProvider);
      final responseMsg = await repo.sendUserMessage(
        text,
        isVoice: isVoice,
        durationSeconds: durationSeconds,
        currentLocale: currentLocale,
      );

      state = state.copyWith(
        messages: [...state.messages, responseMsg],
        isThinking: false,
      );

      // Refresh tasks and notifications
      await ref.read(tasksProvider.notifier).refresh();
      final currentTasks = ref.read(tasksProvider).value ?? [];
      await ref.read(notificationServiceProvider).scheduleTaskReminders(currentTasks);
    } catch (e) {
      final errText = isArabic
          ? 'حدث خطأ أثناء معالجة طلبك. يُرجى التحقق من الاتصال بالخادم والمحاولة مرة أخرى.'
          : 'An error occurred while communicating with the assistant. Please check your connection and try again.';
      final errMessage = ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: errText,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errMessage],
        isThinking: false,
      );
    }
  }

  Future<void> sendVoiceRecording(AudioRecordingResult recording) async {
    final currentLocale = ref.read(localeProvider).languageCode;
    final isArabic = currentLocale == 'ar';

    final userMsgId = _uuid.v4();
    final userMsg = ChatMessageModel(
      id: userMsgId,
      sender: MessageSender.user,
      text: '...',
      timestamp: DateTime.now(),
      isVoice: true,
      audioDurationSeconds: recording.durationSeconds,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    final authState = ref.read(authProvider).value;
    if (authState == null || !authState.isAuthenticated) {
      final errText = isArabic
          ? 'يُرجى تسجيل الدخول أولاً لتتمكن من إرسال تسجيلات صوتية.'
          : 'Please sign in first to send voice recordings.';
      final errMessage = ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: errText,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errMessage],
        isThinking: false,
      );
      return;
    }

    try {
      final repo = ref.read(restTaskRepositoryProvider);
      final respData = await repo.sendVoiceMessage(
        audioBytes: recording.bytes,
        filename: recording.filename,
        mimeType: recording.mimeType,
        durationSeconds: recording.durationSeconds,
      );

      final transcript = respData['transcript'] as String? ?? (isArabic ? 'تسجيل صوتي' : 'Voice recording');
      final assistantMsgJson = respData['assistantMessage'] as Map<String, dynamic>;
      final assistantMsg = ChatMessageModel.fromJson(assistantMsgJson);

      final updatedMessages = state.messages.map((m) {
        if (m.id == userMsgId) {
          return m.copyWith(text: transcript);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: [...updatedMessages, assistantMsg],
        isThinking: false,
      );

      if (respData['tasksMutated'] == true) {
        await ref.read(tasksProvider.notifier).refresh();
        final currentTasks = ref.read(tasksProvider).value ?? [];
        await ref.read(notificationServiceProvider).scheduleTaskReminders(currentTasks);
      }
    } catch (e) {
      final errText = isArabic
          ? 'حدث خطأ أثناء معالجة التسجيل الصوتي. يُرجى المحاولة مرة أخرى.'
          : 'An error occurred while processing your voice recording. Please try again.';
      final errMessage = ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: errText,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errMessage],
        isThinking: false,
      );
    }
  }

  Future<void> undoCreatedTask(String messageId) async {
    final list = List<ChatMessageModel>.from(state.messages);
    final index = list.indexWhere((m) => m.id == messageId);
    if (index != -1 && list[index].actionCard != null) {
      final card = list[index].actionCard!;
      if (card.task != null) {
        final repo = ref.read(restTaskRepositoryProvider);
        try {
          await repo.undoCreateAction(card.task!.id);
        } catch (_) {}
        await ref.read(tasksProvider.notifier).refresh();
      }
      list[index] = list[index].copyWith(
        actionCard: card.copyWith(isUndone: true),
      );
      state = state.copyWith(messages: list);
    }
  }

  Future<void> confirmDeleteTask(String messageId) async {
    final list = List<ChatMessageModel>.from(state.messages);
    final index = list.indexWhere((m) => m.id == messageId);
    if (index != -1 && list[index].actionCard != null) {
      final card = list[index].actionCard!;
      if (card.task != null) {
        final repo = ref.read(restTaskRepositoryProvider);
        try {
          await repo.confirmDeleteAction(card.task!.id);
        } catch (_) {}
        await ref.read(tasksProvider.notifier).refresh();
      }
      list[index] = list[index].copyWith(
        actionCard: card.copyWith(isExecuted: true),
      );
      state = state.copyWith(messages: list);
    }
  }

  void cancelDeleteTask(String messageId) {
    final list = List<ChatMessageModel>.from(state.messages);
    final index = list.indexWhere((m) => m.id == messageId);
    if (index != -1 && list[index].actionCard != null) {
      list[index] = list[index].copyWith(
        actionCard: list[index].actionCard!.copyWith(isExecuted: true),
      );
      state = state.copyWith(messages: list);
    }
  }

  Future<void> resolveConflict(
    String messageId, {
    FreeSlotModel? selectedSlot,
    bool force = false,
  }) async {
    final list = List<ChatMessageModel>.from(state.messages);
    final index = list.indexWhere((m) => m.id == messageId);
    if (index != -1 && list[index].actionCard != null) {
      final card = list[index].actionCard!;
      if (card.task != null) {
        final repo = ref.read(restTaskRepositoryProvider);
        try {
          await repo.resolveConflictAction(
            task: card.task!,
            selectedSlot: selectedSlot,
            force: force,
          );
        } catch (_) {}
        await ref.read(tasksProvider.notifier).refresh();
      }
      list[index] = list[index].copyWith(
        actionCard: card.copyWith(isExecuted: true),
      );
      state = state.copyWith(messages: list);
    }
  }
}

final aiAssistantProvider = NotifierProvider<AiAssistantNotifier, AiAssistantState>(
  AiAssistantNotifier.new,
);
