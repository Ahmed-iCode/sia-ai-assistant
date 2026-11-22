import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/audio_recorder_service.dart';
import '../../../core/theme/app_colors.dart';

class VoiceRecorderInput extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(int durationSeconds) onSendVoice;
  final Function(AudioRecordingResult recording)? onSendAudio;
  final Function(List<int> bytes, String fileName, String? prompt)? onSendFile;
  final AudioRecorderService recorderService;

  const VoiceRecorderInput({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    this.onSendAudio,
    this.onSendFile,
    required this.recorderService,
  });

  @override
  State<VoiceRecorderInput> createState() => _VoiceRecorderInputState();
}

class _AttachedFileInfo {
  final String name;
  final int size;
  final List<int> bytes;

  const _AttachedFileInfo({
    required this.name,
    required this.size,
    required this.bytes,
  });
}

class _VoiceRecorderInputState extends State<VoiceRecorderInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  _AttachedFileInfo? _attachedFile;
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  final List<double> _waveforms = List.generate(14, (_) => 0.2);
  StreamSubscription<double>? _amplitudeSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await widget.recorderService.startRecording();
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied or not available.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _seconds = 0;
    });
    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _seconds++);
      }
    });

    _amplitudeSub = widget.recorderService.amplitudeStream.listen((amp) {
      if (mounted) {
        setState(() {
          _waveforms.removeAt(0);
          final jitter = (Random().nextDouble() * 0.4) - 0.2;
          final value = (amp + jitter).clamp(0.15, 1.0);
          _waveforms.add(value);
        });
      }
    });
  }

  Future<void> _stopAndSendRecording() async {
    _pulseController.stop();
    _pulseController.reset();
    final result = await widget.recorderService.stopRecording();
    _timer?.cancel();
    _amplitudeSub?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _seconds = 0;
      });
      if (result != null) {
        if (widget.onSendAudio != null) {
          widget.onSendAudio!(result);
        } else {
          widget.onSendVoice(result.durationSeconds);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not record audio or recording was empty.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _pulseController.stop();
    _pulseController.reset();
    await widget.recorderService.cancelRecording();
    _timer?.cancel();
    _amplitudeSub?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _seconds = 0;
      });
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final fileSize = (await file.length()) ?? 0;
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.strings.fileTooLargeError),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read file data'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() {
        _attachedFile = _AttachedFileInfo(
          name: file.name,
          size: fileSize,
          bytes: bytes,
        );
      });
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (_attachedFile != null) {
      final file = _attachedFile!;
      setState(() {
        _attachedFile = null;
      });
      _textController.clear();
      if (widget.onSendFile != null) {
        widget.onSendFile!(file.bytes, file.name, text.isEmpty ? null : text);
        return;
      }
    }

    if (text.isEmpty) return;
    _textController.clear();
    widget.onSendText(text);
  }

  String _formatTimer(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isRecording
              ? _buildRecordingBar(context, l10n, theme, isDark)
              : _buildTextInputBar(context, l10n, theme, isDark),
        ),
      ),
    );
  }

  Widget _buildRecordingBar(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    return Row(
      key: const ValueKey('recording_bar'),
      children: [
        // Cancel button
        IconButton(
          tooltip: l10n.strings.cancelRecording,
          icon: const Icon(LucideIcons.x, color: AppColors.error, size: 20),
          onPressed: _cancelRecording,
        ),

        // Pulsing red mic icon
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha((40 + (_pulseController.value * 60)).toInt()),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.mic, color: AppColors.error, size: 16),
            );
          },
        ),
        const SizedBox(width: 10),

        // Timer
        Text(
          _formatTimer(_seconds),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 12),

        // Live Audio Waveform Bars
        Expanded(
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _waveforms.map((h) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 3.5,
                  height: (h * 28).clamp(4.0, 28.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Send Voice Button
        Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: l10n.strings.sendRecording,
            icon: const Icon(LucideIcons.arrowUp, color: Colors.white, size: 18),
            onPressed: _stopAndSendRecording,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, ThemeData theme, bool isDark) {
    final file = _attachedFile!;
    final isPdf = file.name.toLowerCase().endsWith('.pdf');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withAlpha(isDark ? 80 : 50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPdf ? LucideIcons.fileText : LucideIcons.image,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(${_formatFileSize(file.size)})',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _attachedFile = null),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(LucideIcons.x, size: 14, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputBar(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_attachedFile != null)
          _buildAttachmentPreview(context, theme, isDark),
        Row(
          key: const ValueKey('text_bar'),
          children: [
            // Attachment (Paperclip) button
            Container(
              margin: const EdgeInsetsDirectional.only(end: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: l10n.strings.attachFileTooltip,
                icon: const Icon(LucideIcons.paperclip, color: AppColors.primary, size: 18),
                onPressed: _pickAttachment,
              ),
            ),

            // Voice record trigger button
            Container(
              margin: const EdgeInsetsDirectional.only(end: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(isDark ? 35 : 20),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: l10n.strings.micTapToRecord,
                icon: const Icon(LucideIcons.mic, color: AppColors.primary, size: 18),
                onPressed: _startRecording,
              ),
            ),

            // Text input field
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTextMessage(),
                decoration: InputDecoration(
                  hintText: _attachedFile != null
                      ? (l10n.isArabic
                          ? 'أضف تعليمات إضافية أو اضغط إرسال...'
                          : 'Add optional prompt or tap send...')
                      : l10n.strings.aiTypingHint,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Text button
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(LucideIcons.send, color: Colors.white, size: 16),
                onPressed: _sendTextMessage,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
