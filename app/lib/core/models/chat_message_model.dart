import 'ai_action_card_model.dart';

enum MessageSender { user, assistant, system }

class ChatMessageModel {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final bool isVoice;
  final int? audioDurationSeconds;
  final AiActionCardModel? actionCard;

  const ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isVoice = false,
    this.audioDurationSeconds,
    this.actionCard,
  });

  ChatMessageModel copyWith({
    String? id,
    MessageSender? sender,
    String? text,
    DateTime? timestamp,
    bool? isVoice,
    int? audioDurationSeconds,
    AiActionCardModel? actionCard,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isVoice: isVoice ?? this.isVoice,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      actionCard: actionCard ?? this.actionCard,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.name,
      'text': text,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'isVoice': isVoice,
      'audioDurationSeconds': audioDurationSeconds,
      'actionCard': actionCard?.toJson(),
    };
  }

  static DateTime _parseUtcToLocal(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    final str = value.toString().trim();
    if (str.isEmpty) return DateTime.now();
    final hasTimezone = str.endsWith('Z') ||
        str.endsWith('z') ||
        RegExp(r'[+-]\d{2}(:\d{2})?$').hasMatch(str);
    final parsed = DateTime.parse(hasTimezone ? str : '${str}Z');
    return parsed.toLocal();
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      sender: MessageSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => MessageSender.assistant,
      ),
      text: json['text'] as String,
      timestamp: _parseUtcToLocal(json['timestamp']),
      isVoice: json['isVoice'] as bool? ?? false,
      audioDurationSeconds: json['audioDurationSeconds'] as int?,
      actionCard: json['actionCard'] != null
          ? AiActionCardModel.fromJson(json['actionCard'] as Map<String, dynamic>)
          : null,
    );
  }
}
