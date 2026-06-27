library;
import 'dart:async';
import 'dart:typed_data';

enum RecordState { idle, recording, stopped, error }

class RecordConfig {
  final int maxDurationSeconds;
  final int sampleRate;
  final String format;
  const RecordConfig({this.maxDurationSeconds = 60, this.sampleRate = 16000, this.format = 'wav'});
}

class RecordResult {
  final Uint8List audioBytes;
  final String format;
  final double durationSeconds;
  final String? error;
  RecordResult({required this.audioBytes, this.format = 'wav', this.durationSeconds = 0.0, this.error});
  bool get isSuccess => error == null && audioBytes.isNotEmpty;
}

abstract class AudioRecorder {
  RecordState get state;
  RecordConfig get config;
  Future<void> startRecording({RecordConfig? config});
  Future<RecordResult> stopRecording();
  Future<void> cancelRecording();
  Future<void> dispose();
}

class PlatformAudioRecorder implements AudioRecorder {
  @override
  RecordState state = RecordState.idle;
  @override
  RecordConfig config = const RecordConfig();
  bool _isRecording = false;
  DateTime? _recordStartTime;

  @override
  Future<void> startRecording({RecordConfig? config}) async {
    if (_isRecording) return;
    if (config != null) this.config = config;
    _isRecording = true;
    _recordStartTime = DateTime.now();
    state = RecordState.recording;
  }

  @override
  Future<RecordResult> stopRecording() async {
    if (!_isRecording) return RecordResult(audioBytes: Uint8List(0), error: 'Not recording');
    _isRecording = false;
    final dur = _recordStartTime != null ? DateTime.now().difference(_recordStartTime!).inMilliseconds / 1000.0 : 0.0;
    state = RecordState.stopped;
    return RecordResult(audioBytes: Uint8List(0), format: config.format, durationSeconds: dur);
  }

  @override
  Future<void> cancelRecording() async { if (_isRecording) { _isRecording = false; state = RecordState.idle; } }

  @override
  Future<void> dispose() async { await cancelRecording(); }
}
