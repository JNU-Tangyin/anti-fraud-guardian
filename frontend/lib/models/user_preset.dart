import 'package:shared_preferences/shared_preferences.dart';

class UserPreset {
  bool autoHangup;
  double? customThreshold;
  String serverUrl;
  bool enableFeedback;

  UserPreset({this.autoHangup = false, this.customThreshold, this.serverUrl = 'http://10.0.2.2:8000', this.enableFeedback = true});

  factory UserPreset.fromPrefs(SharedPreferences prefs) {
    return UserPreset(
      autoHangup: prefs.getBool('preset_auto_hangup') ?? false,
      customThreshold: prefs.getDouble('preset_threshold'),
      serverUrl: prefs.getString('preset_server_url') ?? 'http://10.0.2.2:8000',
      enableFeedback: prefs.getBool('preset_feedback') ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('preset_auto_hangup', autoHangup);
    if (customThreshold != null) { await prefs.setDouble('preset_threshold', customThreshold!); } else { await prefs.remove('preset_threshold'); }
    await prefs.setString('preset_server_url', serverUrl);
    await prefs.setBool('preset_feedback', enableFeedback);
  }

  UserPreset copyWith({bool? autoHangup, double? customThreshold, String? serverUrl, bool? enableFeedback}) {
    return UserPreset(autoHangup: autoHangup ?? this.autoHangup, customThreshold: customThreshold ?? this.customThreshold, serverUrl: serverUrl ?? this.serverUrl, enableFeedback: enableFeedback ?? this.enableFeedback);
  }
}
