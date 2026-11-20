import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/ai_action_card_model.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/models/free_slot_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import 'conflict_alert_card.dart';
import 'delete_confirm_card.dart';
import 'free_slots_card.dart';
import 'task_created_card.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback onUndoTask;
  final VoidCallback onConfirmDelete;
  final VoidCallback onCancelDelete;
  final Function(FreeSlotModel slot)? onSelectSlot;

  const ChatBubble({
    super.key,
    required this.message,
    required this.onUndoTask,
    required this.onConfirmDelete,
    required this.onCancelDelete,
    this.onSelectSlot,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assistant Avatar (Left if assistant)
          if (!isUser) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(isDark ? 80 : 40),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Image.asset(
                  'assets/images/sia_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Bubble Content
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Text Bubble Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 30 : 10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Voice indicator if audio message
                      if (message.isVoice) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.mic, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              '${message.audioDurationSeconds ?? 3}s • ${l10n.strings.taskSourceVoice}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withAlpha(220),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Message Body text
                      if (isUser)
                        Text(
                          message.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            height: 1.4,
                          ),
                        )
                      else
                        MarkdownBody(
                          data: message.text,
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              final uri = Uri.tryParse(href);
                              if (uri != null) {
                                launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              height: 1.4,
                            ),
                            strong: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            em: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                            listBullet: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              height: 1.4,
                            ),
                            code: theme.textTheme.bodySmall?.copyWith(
                              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              color: AppColors.primary,
                              fontFamily: 'monospace',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Rich Action Card (if attached to assistant message)
                if (message.actionCard != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildActionCard(context, message.actionCard!),
                  ),
                ],

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    DateFormatter.formatTime(message.timestamp, context),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User Avatar (Right if user)
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: const Icon(LucideIcons.user, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, AiActionCardModel actionCard) {
    switch (actionCard.type) {
      case AiCardType.taskCreated:
        return TaskCreatedCard(
          task: actionCard.task!,
          isUndone: actionCard.isUndone,
          onUndo: onUndoTask,
        );
      case AiCardType.conflictAlert:
        return ConflictAlertCard(
          actionCard: actionCard,
          onSelectSlot: (slot) {
            if (onSelectSlot != null) {
              onSelectSlot!(slot);
            }
          },
        );
      case AiCardType.freeSlots:
        return FreeSlotsCard(
          freeSlots: actionCard.freeSlots,
        );
      case AiCardType.deleteConfirm:
        return DeleteConfirmCard(
          task: actionCard.task,
          isExecuted: actionCard.isExecuted,
          onConfirm: onConfirmDelete,
          onCancel: onCancelDelete,
        );
    }
  }
}
