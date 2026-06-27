import 'package:flutter/material.dart';
import '../models/fraud_decision.dart';

class RiskIndicator extends StatelessWidget {
  final RiskLevel level;
  final double score;
  final bool compact;
  const RiskIndicator({super.key, required this.level, required this.score, this.compact = false});

  Color get _color { switch (level) { case RiskLevel.high: return Colors.redAccent; case RiskLevel.medium: return Colors.orangeAccent; case RiskLevel.low: return Colors.greenAccent; } }
  String get _label { switch (level) { case RiskLevel.high: return '高风险'; case RiskLevel.medium: return '中风险'; case RiskLevel.low: return '安全'; } }
  IconData get _icon { switch (level) { case RiskLevel.high: return Icons.warning_rounded; case RiskLevel.medium: return Icons.error_outline; case RiskLevel.low: return Icons.check_circle_outline; } }

  @override
  Widget build(BuildContext context) {
    if (compact) return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _color.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _color)), const SizedBox(width: 6), Text(_label, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600))]));
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _color.withOpacity(0.2))), child: Column(children: [
      Row(children: [Icon(_icon, color: _color, size: 28), const SizedBox(width: 10), Text(_label, style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), Text('${(score * 100).toStringAsFixed(0)}%', style: TextStyle(color: _color, fontSize: 22, fontWeight: FontWeight.w300))]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: score.clamp(0.0, 1.0), backgroundColor: Colors.white10, color: _color, minHeight: 6)),
    ]));
  }
}
