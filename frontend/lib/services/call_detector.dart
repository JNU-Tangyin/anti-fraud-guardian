library;
import 'dart:async';

enum CallState { idle, ringing, offhook, ended }
typedef CallStateCallback = void Function(CallState state, String? phoneNumber);

class CallStateEvent {
  final CallState state;
  final String? phoneNumber;
  final DateTime timestamp;
  CallStateEvent({required this.state, this.phoneNumber, DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

abstract class CallDetector {
  CallState get currentState;
  String? get currentNumber;
  Stream<CallStateEvent> get stateStream;
  Future<void> initialize();
  Future<void> dispose();
}

class AndroidCallDetector implements CallDetector {
  @override CallState currentState = CallState.idle;
  @override String? currentNumber;
  final StreamController<CallStateEvent> _ctrl = StreamController<CallStateEvent>.broadcast();
  @override Stream<CallStateEvent> get stateStream => _ctrl.stream;
  @override Future<void> initialize() async { _ctrl.add(CallStateEvent(state: CallState.idle)); }
  @override Future<void> dispose() async { await _ctrl.close(); }
}

class IOSCallDetector implements CallDetector {
  @override CallState currentState = CallState.idle;
  @override String? currentNumber;
  final StreamController<CallStateEvent> _ctrl = StreamController<CallStateEvent>.broadcast();
  @override Stream<CallStateEvent> get stateStream => _ctrl.stream;
  @override Future<void> initialize() async { _ctrl.add(CallStateEvent(state: CallState.idle)); }
  @override Future<void> dispose() async { await _ctrl.close(); }
}

class HarmonyCallDetector implements CallDetector {
  @override CallState currentState = CallState.idle;
  @override String? currentNumber;
  final StreamController<CallStateEvent> _ctrl = StreamController<CallStateEvent>.broadcast();
  @override Stream<CallStateEvent> get stateStream => _ctrl.stream;
  @override Future<void> initialize() async { _ctrl.add(CallStateEvent(state: CallState.idle)); }
  @override Future<void> dispose() async { await _ctrl.close(); }
}

CallDetector createCallDetector() => AndroidCallDetector();
