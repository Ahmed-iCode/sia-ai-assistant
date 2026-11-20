import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../utils/audio_file_reader.dart';

class AudioRecordingResult {
  final List<int> bytes;
  final String filename;
  final String mimeType;
  final int durationSeconds;

  const AudioRecordingResult({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.durationSeconds,
  });
}

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  DateTime? _recordingStartTime;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _fallbackTicker;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  bool get isRecording => _recordingStartTime != null;

  int get elapsedSeconds {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    final permitted = await hasPermission();
    if (!permitted) {
      return false;
    }

    try {
      final config = kIsWeb
          ? const RecordConfig(encoder: AudioEncoder.opus)
          : const RecordConfig(encoder: AudioEncoder.aacLc);

      final targetPath = getTempAudioFilePath();
      await _audioRecorder.start(config, path: targetPath);
      _recordingStartTime = DateTime.now();

      // Listen to real amplitudes from microphone
      try {
        _amplitudeSub?.cancel();
        _amplitudeSub = _audioRecorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((amp) {
          // Normalize amp.current (typically -60dB to 0dB) to 0.1 - 1.0
          final normalized = ((amp.current + 60) / 60).clamp(0.1, 1.0);
          _amplitudeController.add(normalized);
        });
      } catch (_) {
        // Fallback ticker if platform does not support onAmplitudeChanged
        _startFallbackTicker();
      }

      return true;
    } catch (e) {
      debugPrint('Failed to start real recording: $e');
      return false;
    }
  }

  void _startFallbackTicker() {
    _fallbackTicker?.cancel();
    _fallbackTicker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isRecording) {
        timer.cancel();
        return;
      }
      final tick = timer.tick;
      final val = (0.2 + (0.6 * (1 + (tick % 7)) / 7)).clamp(0.1, 1.0);
      _amplitudeController.add(val);
    });
  }

  Future<AudioRecordingResult?> stopRecording() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _fallbackTicker?.cancel();
    _fallbackTicker = null;

    final duration = elapsedSeconds > 0 ? elapsedSeconds : 1;
    _recordingStartTime = null;

    try {
      final recordedPath = await _audioRecorder.stop();
      if (recordedPath == null || recordedPath.isEmpty) {
        return null;
      }

      final bytes = await readAudioBytes(recordedPath);
      if (bytes.isEmpty) {
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = kIsWeb ? 'rec_$timestamp.webm' : 'rec_$timestamp.m4a';
      final mimeType = kIsWeb ? 'audio/webm' : 'audio/m4a';

      return AudioRecordingResult(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        durationSeconds: duration,
      );
    } catch (e) {
      debugPrint('Error stopping recording and reading bytes: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _fallbackTicker?.cancel();
    _fallbackTicker = null;
    _recordingStartTime = null;

    try {
      await _audioRecorder.stop();
    } catch (_) {}
  }

  void dispose() {
    _amplitudeSub?.cancel();
    _fallbackTicker?.cancel();
    _amplitudeController.close();
    _audioRecorder.dispose();
  }
}
