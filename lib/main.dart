import 'package:flutter/material.dart';
import 'controllers/db_service.dart';
import 'views/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.init();
  runApp(const CarSpotterApp());
}

class CarSpotterApp extends StatelessWidget {
  const CarSpotterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarSpotter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, // <-- Corretto da useMaterialDesign a useMaterial3
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEEEEE4),
        primaryColor: const Color(0xFF10B981),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
