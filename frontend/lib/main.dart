library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/fraud_provider.dart';
import 'screens/home_screen.dart';
import 'screens/call_alert_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(const AntiFraudApp());
}

class AntiFraudApp extends StatelessWidget {
  const AntiFraudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FraudProvider()..initialize(serverUrl: 'http://10.0.2.2:8000'),
      child: MaterialApp(
        title: '反诈卫士',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0E21),
          primaryColor: Colors.cyanAccent,
          colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, secondary: Colors.blueAccent, surface: Color(0xFF141832)),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
        ),
        home: const HomeScreen(),
        routes: {'/alert': (_) => const CallAlertScreen()},
      ),
    );
  }
}
