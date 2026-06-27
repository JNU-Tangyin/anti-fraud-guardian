import 'package:flutter/foundation.dart';

enum RiskLevel { low, medium, high }
enum RecommendedAction { allow, warn, hangup }

class EmbeddingDetail {
  final double similarity;
  final String? matchedLabel;
  final List<Map<String, dynamic>> topK;

  EmbeddingDetail({required this.similarity, this.matchedLabel, this.topK = const []});

  factory EmbeddingDetail.fromJson(Map<String, dynamic> json) {
    return EmbeddingDetail(
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      matchedLabel: json['matched_label'] as String?,
      topK: List<Map<String, dynamic>>.from(json['top_k'] ?? []),
    );
  }
}

class AnalyzeResult {
  final String requestId;
  final RiskLevel riskLevel;
  final double riskScore;
  final RecommendedAction recommendedAction;
  final EmbeddingDetail? textEmbedding;
  final EmbeddingDetail? audioEmbedding;
  final double fusedSimilarity;
  final double processingTimeMs;
  final String? transcriptPreview;

  AnalyzeResult({required this.requestId, required this.riskLevel, required this.riskScore, required this.recommendedAction, this.textEmbedding, this.audioEmbedding, this.fusedSimilarity = 0.0, this.processingTimeMs = 0.0, this.transcriptPreview});

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) {
    return AnalyzeResult(
      requestId: json['request_id'] as String? ?? '',
      riskLevel: _parseRiskLevel(json['risk_level'] as String?),
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      recommendedAction: _parseAction(json['recommended_action'] as String?),
      textEmbedding: json['text_embedding'] != null ? EmbeddingDetail.fromJson(json['text_embedding']) : null,
      audioEmbedding: json['audio_embedding'] != null ? EmbeddingDetail.fromJson(json['audio_embedding']) : null,
      fusedSimilarity: (json['fused_similarity'] as num?)?.toDouble() ?? 0.0,
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      transcriptPreview: json['transcript_preview'] as String?,
    );
  }

  static RiskLevel _parseRiskLevel(String? s) {
    switch (s) { case 'high': return RiskLevel.high; case 'medium': return RiskLevel.medium; default: return RiskLevel.low; }
  }

  static RecommendedAction _parseAction(String? s) {
    switch (s) { case 'hangup': return RecommendedAction.hangup; case 'warn': return RecommendedAction.warn; default: return RecommendedAction.allow; }
  }

  String get riskLabel {
    switch (riskLevel) {
      case RiskLevel.high: return '⚠️ 高风险 — 疑似诈骗';
      case RiskLevel.medium: return '⚡ 中风险 — 请保持警惕';
      case RiskLevel.low: return '✅ 低风险 — 正常通话';
    }
  }
}
