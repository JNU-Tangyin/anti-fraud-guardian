import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fraud_provider.dart';
import '../models/fraud_decision.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('反诈卫士'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))],
      ),
      body: Consumer<FraudProvider>(
        builder: (context, provider, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _StatusBar(provider: provider),
                  const SizedBox(height: 32),
                  Expanded(child: _buildPhase(context, provider)),
                  if (provider.phase == AppPhase.idle) _DemoSection(provider: provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhase(BuildContext context, FraudProvider p) {
    switch (p.phase) {
      case AppPhase.idle: return _idle();
      case AppPhase.callRinging: return _ringing(p);
      case AppPhase.recording: return _recording(p);
      case AppPhase.analyzing: return _analyzing();
      case AppPhase.resultReady: return _result(p);
      case AppPhase.callEnded: return _idle();
    }
  }

  Widget _idle() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_outlined, size: 80, color: Colors.white.withOpacity(0.2)), const SizedBox(height: 20), const Text('等待来电', style: TextStyle(color: Colors.white54, fontSize: 18)), const SizedBox(height: 8), const Text('反诈卫士在后台守护您的每一通电话', style: TextStyle(color: Colors.white24, fontSize: 14))]));

  Widget _ringing(FraudProvider p) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.phone_in_talk, size: 64, color: Colors.orangeAccent), const SizedBox(height: 16), Text(p.currentNumber ?? '未知号码', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300)), const SizedBox(height: 8), const Text('来电中 — 接听后自动检测', style: TextStyle(color: Colors.white38, fontSize: 14))]));

  Widget _recording(FraudProvider p) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.cyanAccent)), const SizedBox(height: 24), const Text('正在采集通话样本...', style: TextStyle(color: Colors.white70, fontSize: 18)), const SizedBox(height: 8), Text('${p.currentNumber ?? "通话中"}', style: const TextStyle(color: Colors.white30, fontSize: 14)), const SizedBox(height: 4), const Text('最多60秒后自动分析', style: TextStyle(color: Colors.white24, fontSize: 12))]));

  Widget _analyzing() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.blueAccent)), SizedBox(height: 20), Text('AI 分析中...', style: TextStyle(color: Colors.white54, fontSize: 18)), SizedBox(height: 8), Text('语音识别 → Embedding → 风险比对', style: TextStyle(color: Colors.white24, fontSize: 13))]));

  Widget _result(FraudProvider p) {
    final r = p.lastResult;
    if (r == null) return _idle();
    final isHigh = r.riskLevel == RiskLevel.high;
    final isMedium = r.riskLevel == RiskLevel.medium;
    return SingleChildScrollView(
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: (isHigh ? Colors.red : isMedium ? Colors.orange : Colors.green).withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isHigh ? Colors.redAccent : isMedium ? Colors.orangeAccent : Colors.greenAccent).withOpacity(0.3))),
        child: Column(children: [
          Icon(isHigh ? Icons.warning_rounded : isMedium ? Icons.error_outline : Icons.check_circle_outline, size: 64, color: isHigh ? Colors.redAccent : isMedium ? Colors.orangeAccent : Colors.greenAccent),
          const SizedBox(height: 12),
          Text(r.riskLabel, style: TextStyle(color: isHigh ? Colors.redAccent : isMedium ? Colors.orangeAccent : Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('综合风险分: ${(r.fusedSimilarity * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 24),
          Text('分析耗时: ${r.processingTimeMs.toStringAsFixed(0)}ms', style: const TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => p.submitFeedback('fraud'), style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: const Text('✓ 确认诈骗')),
            const SizedBox(width: 12),
            TextButton(onPressed: () => p.submitFeedback('normal'), style: TextButton.styleFrom(foregroundColor: Colors.greenAccent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: const Text('✗ 误报')),
          ]),
        ]),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final FraudProvider provider;
  const _StatusBar({required this.provider});
  @override
  Widget build(BuildContext context) {
    final online = provider.isBackendOnline;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? Colors.greenAccent : Colors.redAccent, boxShadow: [BoxShadow(color: (online ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4), blurRadius: 8, spreadRadius: 2)])),
      const SizedBox(width: 8),
      Text(online ? '保护中' : '后端离线', style: TextStyle(color: online ? Colors.greenAccent : Colors.redAccent, fontSize: 13)),
      const Spacer(),
      if (provider.isLocalReady) const Text('本地就绪', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
    ]);
  }
}

class _DemoSection extends StatelessWidget {
  final FraudProvider provider;
  const _DemoSection({required this.provider});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(children: [
      const Text('Demo 模式', style: TextStyle(color: Colors.white24, fontSize: 12)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(onPressed: () => provider.manualAnalyze('test'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.2), foregroundColor: Colors.green, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), child: const Text('模拟正常通话')),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: () => provider.manualAnalyze('test'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2), foregroundColor: Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), child: const Text('模拟诈骗通话')),
      ]),
    ]));
  }
}
