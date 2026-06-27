import 'package:dio/dio.dart';
import '../models/fraud_decision.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30), headers: {'Content-Type': 'application/json'}));

  Future<AnalyzeResult> analyzeAudio({required String audioBase64, String audioFormat = 'wav', String? callerNumber, required String deviceId}) async {
    final resp = await _dio.post('/api/v1/analyze', data: {'audio_base64': audioBase64, 'audio_format': audioFormat, 'caller_number': callerNumber, 'device_id': deviceId});
    if (resp.statusCode == 200) return AnalyzeResult.fromJson(resp.data as Map<String, dynamic>);
    throw DioException(requestOptions: resp.requestOptions, response: resp, message: 'Analyze failed');
  }

  Future<bool> healthCheck() async {
    try { return (await _dio.get('/api/v1/health')).statusCode == 200; } catch (_) { return false; }
  }

  Future<void> submitFeedback({required String requestId, required String label, String? notes}) async {
    await _dio.post('/api/v1/feedback', data: {'request_id': requestId, 'user_label': label, 'notes': notes});
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return (await _dio.get('/api/v1/cache/stats')).data as Map<String, dynamic>;
  }
}
