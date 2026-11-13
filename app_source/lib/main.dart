import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/design_tokens.dart';
import 'ui/horizon_intro.dart';
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
  // Arranque en frío del proceso: con la animación Horizonte (una vez).
  runApp(const VoiceBubbleApp(showIntro: true));
}

class VoiceBubbleApp extends StatelessWidget {
  /// Animación de arranque sobre Inicio (design.md §15). Apagada por
  /// defecto: solo `main()` la pide; un test la enciende explícitamente.
  /// Igual se muestra una sola vez por proceso.
  final bool showIntro;

  const VoiceBubbleApp({super.key, this.showIntro = false});

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
          home: showIntro
              ? const HorizonIntroHost(homeBuilder: _homeWithHoleKey)
              : const HomeScreen(),
        );
      },
    );
  }
}

Widget _homeWithHoleKey(GlobalKey holeKey) => HomeScreen(holeKey: holeKey);
