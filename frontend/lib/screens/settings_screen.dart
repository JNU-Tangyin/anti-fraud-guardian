import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fraud_provider.dart';
import '../models/user_preset.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverCtrl;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: context.read<FraudProvider>().preset.serverUrl);
  }

  @override
  void dispose() { _serverCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(title: const Text('设置'), backgroundColor: Colors.transparent, elevation: 0),
      body: Consumer<FraudProvider>(
        builder: (context, p, _) {
          final preset = p.preset;
          return ListView(padding: const EdgeInsets.all(20), children: [
            _Section('通话保护'),
            _SwitchTile(icon: Icons.phone_callback_rounded, title: '高风险自动挂断', subtitle: '检测到高风险诈骗通话时自动挂断', value: preset.autoHangup, onChanged: (v) => p.updatePreset(preset.copyWith(autoHangup: v))),
            const SizedBox(height: 20),
            _Section('检测灵敏度'),
            _SwitchTile(icon: Icons.tune, title: '自定义阈值', subtitle: '相似度超过此值视为高风险 (当前: ${preset.customThreshold?.toStringAsFixed(2) ?? "默认0.75"})', value: preset.customThreshold != null, onChanged: (v) => p.updatePreset(preset.copyWith(customThreshold: v ? 0.75 : null))),
            const SizedBox(height: 20),
            _Section('服务器'),
            _FieldTile(icon: Icons.dns_outlined, title: '后端地址', ctrl: _serverCtrl, onSubmit: (v) => p.updatePreset(preset.copyWith(serverUrl: v))),
            const SizedBox(height: 20),
            _Section('隐私'),
            _SwitchTile(icon: Icons.feedback_outlined, title: '匿名反馈', subtitle: '匿名提交样本帮助改进模型', value: preset.enableFeedback, onChanged: (v) => p.updatePreset(preset.copyWith(enableFeedback: v))),
            const SizedBox(height: 40),
            _Section('关于'),
            const ListTile(leading: Icon(Icons.info_outline, color: Colors.white38), title: Text('反诈卫士 v0.1.0', style: TextStyle(color: Colors.white70)), subtitle: Text('基于通话内容 Embedding 的智能反诈引擎', style: TextStyle(color: Colors.white30, fontSize: 12))),
          ]);
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text(title, style: TextStyle(color: Colors.cyanAccent.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)));
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)), child: SwitchListTile(secondary: Icon(icon, color: Colors.white38), title: Text(title, style: const TextStyle(color: Colors.white70)), subtitle: Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 12)), value: value, onChanged: onChanged, activeColor: Colors.cyanAccent, contentPadding: const EdgeInsets.symmetric(horizontal: 12)));
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final TextEditingController ctrl;
  final ValueChanged<String> onSubmit;
  const _FieldTile({required this.icon, required this.title, required this.ctrl, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)), child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white70, fontSize: 14), decoration: InputDecoration(icon: Icon(icon, color: Colors.white38), labelText: title, labelStyle: const TextStyle(color: Colors.white38), border: InputBorder.none), onSubmitted: onSubmit));
}
