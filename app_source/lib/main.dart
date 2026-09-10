import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/design_tokens.dart';
import 'ui/theme_mode.dart';
import 'screens/home_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Historial persistente FIFO-20: sin purga al arrancar.
  try {
    final prefs = await SharedPreferences.getInstance();
    appThemeMode.value =
        themeModeFromStorage(prefs.getString('theme_mode') ?? 'sistema');
  } catch (_) {}
  runApp(const VoiceBubbleApp());
}

class VoiceBubbleApp extends StatelessWidget {
  const VoiceBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'VoiceBubble STT',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
