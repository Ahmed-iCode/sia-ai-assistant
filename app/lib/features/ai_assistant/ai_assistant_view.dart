import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'ai_assistant_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/quick_prompt_chips.dart';
import 'widgets/voice_recorder_input.dart';

class AiAssistantView extends ConsumerStatefulWidget {
  const AiAssistantView({super.key});

  @override
  ConsumerState<AiAssistantView> createState() => _AiAssistantViewState();
}

class _AiAssistantViewState extends ConsumerState<AiAssistantView> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final aiState = ref.watch(aiAssistantProvider);
    final recorderService = ref.watch(audioRecorderServiceProvider);

    ref.listen(aiAssistantProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Image.asset(
                  'assets/images/sia_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.strings.aiAssistantTitle,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Ready • AI Powered',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: aiState.messages.length + (aiState.isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == aiState.messages.length) {
                  return _buildThinkingIndicator(context, theme, isDark);
                }
                final message = aiState.messages[index];
                return ChatBubble(
                  message: message,
                  onUndoTask: () {
                    ref.read(aiAssistantProvider.notifier).undoCreatedTask(message.id);
                  },
                  onConfirmDelete: () {
                    ref.read(aiAssistantProvider.notifier).confirmDeleteTask(message.id);
                  },
                  onCancelDelete: () {
                    ref.read(aiAssistantProvider.notifier).cancelDeleteTask(message.id);
                  },
                  onSelectSlot: (slot) {
                    ref.read(aiAssistantProvider.notifier).resolveConflict(message.id, selectedSlot: slot);
                  },
                );
              },
            ),
          ),

          // Quick Prompt Chips
          QuickPromptChips(
            onSelectPrompt: (prompt) {
              ref.read(aiAssistantProvider.notifier).sendMessage(prompt);
            },
          ),
          const SizedBox(height: 8),

          // Voice & Text Input Bar
          VoiceRecorderInput(
            recorderService: recorderService,
            onSendText: (text) {
              ref.read(aiAssistantProvider.notifier).sendMessage(text);
            },
            onSendAudio: (recording) {
              ref.read(aiAssistantProvider.notifier).sendVoiceRecording(recording);
            },
            onSendVoice: (duration) {
              final isArabic = l10n.isArabic;
              final prompt = isArabic
                  ? 'طلب صوتي: مراجعة المواعيد وأوقات الفراغ'
                  : 'Voice Command: Schedule review & free slots';
              ref.read(aiAssistantProvider.notifier).sendMessage(
                    prompt,
                    isVoice: true,
                    durationSeconds: duration,
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI Thinking...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
