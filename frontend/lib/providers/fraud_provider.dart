library;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/fraud_decision.dart';
import '../models/user_preset.dart';
import '../services/api_client.dart';
import '../services/audio_recorder.dart';
import '../services/call_detector.dart';
import '../services/local_engine.dart';

enum AppPhase { idle, callRinging, recording, analyzing, resultReady, callEnded }

class FraudProvider extends ChangeNotifier {
  late ApiClient _apiClient;
  CallDetector? _callDetector;
  AudioRecorder? _audioRecorder;
  late LocalInferenceEngine _localEngine;
  LocalEmbedder? _embedder;

  AppPhase _phase = AppPhase.idle;
  CallState _callState = CallState.idle;
  String? _currentNumber;
  AnalyzeResult? _lastResult;
  String? _errorMessage;
  UserPreset _preset = UserPreset();
  Map<String, dynamic>? _cacheStats;
  bool _isBackendOnline = false;

  StreamSubscription<CallStateEvent>? _callSub;
  Timer? _recordingTimer;
  final _uuid = const Uuid();

  AppPhase get phase => _phase;
  CallState get callState => _callState;
  String? get currentNumber => _currentNumber;
  AnalyzeResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  UserPreset get preset => _preset;
  Map<String, dynamic>? get cacheStats => _cacheStats;
  bool get isBackendOnline => _isBackendOnline;
  LocalInferenceEngine get localEngine => _localEngine;
  bool get isLocalReady => _localEngine.isReady;

  Future<void> initialize({required String serverUrl, CallDetector? callDetector, AudioRecorder? audioRecorder}) async {
    _apiClient = ApiClient(baseUrl: serverUrl);
    _callDetector = callDetector ?? createCallDetector();
    _audioRecorder = audioRecorder ?? PlatformAudioRecorder();
    _localEngine = LocalInferenceEngine(apiClient: _apiClient);
    _embedder = OnnxEmbedder();
    final results = await Future.wait([_apiClient.healthCheck(), _localEngine.initialize()]);
    _isBackendOnline = results[0] as bool;
    final manifest = _localEngine.manifest;
    if (manifest != null && manifest.modelFingerprint.isNotEmpty) {
      (_embedder as OnnxEmbedder).setExpectedFingerprint(manifest.modelFingerprint);
    }
    final prefs = await SharedPreferences.getInstance();
    _preset = UserPreset.fromPrefs(prefs);
    await _callDetector!.initialize();
    _callSub = _callDetector!.stateStream.listen(_onCallStateChanged);
    notifyListeners();
  }

  void _onCallStateChanged(CallStateEvent event) {
    _callState = event.state;
    _currentNumber = event.phoneNumber;
    switch (event.state) {
      case CallState.ringing: _phase = AppPhase.callRinging; _lastResult = null; break;
      case CallState.offhook: _startRecording(); break;
      case CallState.ended: _phase = AppPhase.callEnded; _stopRecording(); break;
      case CallState.idle: _phase = AppPhase.idle; break;
    }
    notifyListeners();
  }

  Future<void> _startRecording() async {
    _phase = AppPhase.recording; _errorMessage = null; notifyListeners();
    try {
      await _audioRecorder?.startRecording(config: const RecordConfig(maxDurationSeconds: 60));
      _recordingTimer = Timer(const Duration(seconds: 60), () async { await analyzeRecording(); });
    } catch (e) { _errorMessage = '录音失败: $e'; _phase = AppPhase.idle; notifyListeners(); }
  }

  Future<void> analyzeRecording() async {
    _recordingTimer?.cancel();
    if (_phase != AppPhase.recording) return;
    _phase = AppPhase.analyzing; notifyListeners();
    try {
      final result = await _audioRecorder?.stopRecording();
      if (result == null || !result.isSuccess) { _errorMessage = result?.error ?? '录音为空'; _phase = AppPhase.idle; notifyListeners(); return; }

      if (_localEngine.isReady && _embedder != null) {
        try {
          final emb = await _embedder!.embedFromAudio(result.toBase64());
          final match = _localEngine.match(emb);
          if (_preset.enableFeedback) _localEngine.uploadEmbedding(embedding: emb);
        } catch (e) { debugPrint('[FraudProvider] local match: $e'); }
      }

      AnalyzeResult? cloudResult;
      if (_isBackendOnline) {
        try {
          cloudResult = await _apiClient.analyzeAudio(audioBase64: result.toBase64(), audioFormat: result.format, callerNumber: _currentNumber, deviceId: _uuid.v4());
        } catch (e) { debugPrint('[FraudProvider] cloud: $e'); }
      }
      if (cloudResult != null) _lastResult = cloudResult;
      _phase = AppPhase.resultReady;
      if (_lastResult?.riskLevel == RiskLevel.high && _preset.autoHangup) await _hangupCall();
    } catch (e) { _errorMessage = '分析失败: $e'; _phase = AppPhase.idle; }
    notifyListeners();
  }

  Future<void> manualAnalyze(String audio) async {
    _phase = AppPhase.analyzing; notifyListeners();
    try {
      if (_isBackendOnline) {
        _lastResult = await _apiClient.analyzeAudio(audioBase64: audio, audioFormat: 'wav', deviceId: _uuid.v4());
      }
      _phase = AppPhase.resultReady;
    } catch (e) { _errorMessage = '失败: $e'; _phase = AppPhase.idle; }
    notifyListeners();
  }

  Future<void> _hangupCall() async { debugPrint('[FraudProvider] Auto-hangup'); }
  Future<void> _stopRecording() async { _recordingTimer?.cancel(); try { await _audioRecorder?.cancelRecording(); } catch (_) {} }

  Future<void> submitFeedback(String label) async {
    if (_lastResult == null) return;
    try { await _apiClient.submitFeedback(requestId: _lastResult!.requestId, label: label); } catch (_) {}
  }

  Future<void> updatePreset(UserPreset p) async { _preset = p; await _preset.save(); notifyListeners(); }
  void reset() { _phase = AppPhase.idle; _lastResult = null; _errorMessage = null; notifyListeners(); }

  @override
  void dispose() { _callSub?.cancel(); _recordingTimer?.cancel(); _callDetector?.dispose(); _audioRecorder?.dispose(); super.dispose(); }
}
