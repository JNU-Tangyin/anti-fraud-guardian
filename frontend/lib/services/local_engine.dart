import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class CentroidEntry {
  final int clusterId;
  final List<double> centroid;
  final double radius;
  final int size;
  final double purity;
  final int version;
  CentroidEntry({required this.clusterId, required this.centroid, required this.radius, required this.size, required this.purity, required this.version});
  factory CentroidEntry.fromJson(Map<String, dynamic> json) => CentroidEntry(clusterId: json['cluster_id'] as int? ?? 0, centroid: (json['centroid'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [], radius: (json['radius'] as num?)?.toDouble() ?? 0.0, size: json['size'] as int? ?? 0, purity: (json['purity'] as num?)?.toDouble() ?? 0.0, version: json['version'] as int? ?? 1);
}

class CentroidsManifest {
  final int version;
  final String generatedAt, model, modelFingerprint;
  final int dim, nCentroids;
  final double thresholdHigh, thresholdMedium;
  final List<CentroidEntry> centroids;
  bool get isEmpty => centroids.isEmpty;
  CentroidsManifest({required this.version, required this.generatedAt, required this.model, required this.modelFingerprint, required this.dim, required this.nCentroids, required this.thresholdHigh, required this.thresholdMedium, required this.centroids});
  factory CentroidsManifest.fromJson(Map<String, dynamic> json) => CentroidsManifest(version: json['version'] as int? ?? 0, generatedAt: json['generated_at'] as String? ?? '', model: json['model'] as String? ?? '', modelFingerprint: json['model_fingerprint'] as String? ?? '', dim: json['dim'] as int? ?? 0, nCentroids: json['n_centroids'] as int? ?? 0, thresholdHigh: (json['threshold_high'] as num?)?.toDouble() ?? 0.75, thresholdMedium: (json['threshold_medium'] as num?)?.toDouble() ?? 0.55, centroids: (json['centroids'] as List<dynamic>?)?.map((c) => CentroidEntry.fromJson(c as Map<String, dynamic>)).toList() ?? []);
}

class LocalMatchResult {
  final bool isFraud;
  final double maxSimilarity;
  final int? matchedClusterId;
  final double matchedPurity;
  final int matchedClusterSize;
  final String riskLevel;
  LocalMatchResult({required this.isFraud, required this.maxSimilarity, this.matchedClusterId, this.matchedPurity = 0.0, this.matchedClusterSize = 0, this.riskLevel = 'low'});
}

abstract class LocalEmbedder {
  Future<List<double>> embedFromAudio(String audioFilePath);
  Future<List<double>> embedFromText(String text);
  int get embeddingDim;
  bool get isLoaded;
}

class OnnxEmbedder implements LocalEmbedder {
  bool _loaded = false;
  String? _expectedFingerprint;
  @override int get embeddingDim => 384;
  @override bool get isLoaded => _loaded;
  void setExpectedFingerprint(String fp) { _expectedFingerprint = fp; }
  Future<bool> loadModel(String modelPath) async { _loaded = true; return true; }
  @override Future<List<double>> embedFromAudio(String afp) async { if (!_loaded) await loadModel('model.onnx'); return _mock(); }
  @override Future<List<double>> embedFromText(String text) async { if (!_loaded) await loadModel('model.onnx'); return _mock(); }
  List<double> _mock() { final rng = math.Random(42); final vec = List<double>.generate(384, (_) => rng.nextDouble() * 2 - 1); final norm = math.sqrt(vec.fold(0.0, (s, v) => s + v * v)); return vec.map((v) => v / norm).toList(); }
}

class LocalInferenceEngine {
  final ApiClient _apiClient;
  CentroidsManifest? _manifest;
  bool _isReady = false;
  String? _error;
  CentroidsManifest? get manifest => _manifest;
  bool get isReady => _isReady;
  String? get error => _error;

  LocalInferenceEngine({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('centroids_manifest');
      if (cached != null) { _manifest = CentroidsManifest.fromJson(jsonDecode(cached) as Map<String, dynamic>); _isReady = !_manifest!.isEmpty; }
      await _sync();
    } catch (e) { _error = 'init failed: $e'; }
  }

  Future<void> _sync() async {
    try {
      final resp = await _apiClient._dio.get('/api/v1/centroids', queryParameters: {'version': _manifest?.version ?? 0});
      if (resp.statusCode == 200) {
        final m = CentroidsManifest.fromJson(resp.data as Map<String, dynamic>);
        if (m.version > (_manifest?.version ?? 0) || _manifest == null) {
          _manifest = m; _isReady = !m.isEmpty;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('centroids_manifest', jsonEncode(resp.data));
        }
      }
    } catch (e) { debugPrint('[LocalEngine] sync failed: $e'); }
  }

  LocalMatchResult match(List<double> embedding) {
    if (_manifest == null || _manifest!.isEmpty) return LocalMatchResult(isFraud: false, maxSimilarity: 0.0);
    double maxSim = 0.0;
    int? bestId; double bestPurity = 0.0; int bestSize = 0;
    for (final c in _manifest!.centroids) {
      double dot = 0;
      for (int i = 0; i < embedding.length && i < c.centroid.length; i++) dot += embedding[i] * c.centroid[i];
      if (dot > maxSim) { maxSim = dot; bestId = c.clusterId; bestPurity = c.purity; bestSize = c.size; }
    }
    String risk; bool fraud;
    if (maxSim >= _manifest!.thresholdHigh) { risk = 'high'; fraud = true; }
    else if (maxSim >= _manifest!.thresholdMedium) { risk = 'medium'; fraud = true; }
    else { risk = 'low'; fraud = false; }
    return LocalMatchResult(isFraud: fraud, maxSimilarity: maxSim, matchedClusterId: bestId, matchedPurity: bestPurity, matchedClusterSize: bestSize, riskLevel: risk);
  }

  Future<void> uploadEmbedding({required List<double> embedding, String embeddingType = 'text', String? label, String? sourceText}) async {
    try { await _apiClient._dio.post('/api/v1/embeddings/upload', data: {'embedding': embedding, 'embedding_type': embeddingType, 'label': label, 'source_text': sourceText}); } catch (_) {}
  }
}
