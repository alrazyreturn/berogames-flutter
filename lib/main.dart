import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ← مهم: ننتظر تحميل بيانات الجلسة قبل تشغيل التطبيق
  final userProvider = UserProvider();
  await userProvider.loadFromStorage();

  runApp(
    ChangeNotifierProvider.value(
      value: userProvider,
      child: const BeroGamesApp(),
    ),
  );
}

class BeroGamesApp extends StatelessWidget {
  const BeroGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeroGames',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
