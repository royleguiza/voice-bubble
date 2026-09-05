import 'package:flutter/material.dart';
import 'ui/design_tokens.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Historial persistente FIFO-20: sin purga al arrancar.
  runApp(const VoiceBubbleApp());
}

class VoiceBubbleApp extends StatelessWidget {
  const VoiceBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceBubble STT',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
