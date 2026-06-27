import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fraud_provider.dart';
import '../models/fraud_decision.dart';

class CallAlertScreen extends StatelessWidget {
  const CallAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FraudProvider>(
      builder: (context, p, _) {
        final r = p.lastResult;
        if (r == null) return const SizedBox.shrink();
        final isHigh = r.riskLevel == RiskLevel.high;
        return Scaffold(
          backgroundColor: Colors.black87,
          body: SafeArea(
            child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: (isHigh ? Colors.red : Colors.orange).withOpacity(0.15), border: Border.all(color: (isHigh ? Colors.redAccent : Colors.orangeAccent).withOpacity(0.4), width: 2)), child: Icon(isHigh ? Icons.warning_rounded : Icons.help_outline, size: 48, color: isHigh ? Colors.redAccent : Colors.orangeAccent)),
              const SizedBox(height: 24),
              Text(isHigh ? '⚠️ 高风险通话' : '⚡ 疑似风险通话', style: TextStyle(color: isHigh ? Colors.redAccent : Colors.orangeAccent, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(isHigh ? 'AI 检测到此通话与已知诈骗内容高度相似
建议立即挂断！' : 'AI 检测到此通话存在异常
请保持警惕，谨慎对待', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 15, height: 1.5)),
              const SizedBox(height: 8),
              Text('综合风险分: ${(r.fusedSimilarity * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white30, fontSize: 13)),
              const SizedBox(height: 32),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('继续通话'))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(onPressed: () { p.submitFeedback('fraud'); Navigator.pop(context); p.reset(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('立即挂断', style: TextStyle(fontWeight: FontWeight.bold)))),
              ]),
              const SizedBox(height: 12),
              TextButton(onPressed: () { p.submitFeedback('normal'); Navigator.pop(context); }, child: const Text('这是误报，标记为正常通话', style: TextStyle(color: Colors.white24, fontSize: 13))),
            ])),
          ),
        );
      },
    );
  }
}
