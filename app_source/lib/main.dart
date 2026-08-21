import 'package:flutter/material.dart';

const Color _kAccentLight = Color(0xFF007AFF);
const Color _kAccentDark = Color(0xFF0A84FF);
const Color _kRecording = Color(0xFFFF3B30);

void main() {
  runApp(const VoiceBubbleApp());
}

class VoiceBubbleApp extends StatelessWidget {
  const VoiceBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceBubble STT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _kAccentLight),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kAccentDark,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _grabando = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AppBar(
        title: Text('VoiceBubble STT'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 96,
              color: cs.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _grabando ? 'Grabando…' : 'Listo para transcribir',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Hito 0 – Setup base funcionando',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => setState(() => _grabando = !_grabando),
        backgroundColor: _grabando ? _kRecording : null,
        foregroundColor: _grabando ? Colors.white : null,
        child: Icon(_grabando ? Icons.stop_rounded : Icons.mic_rounded, size: 36),
      ),
    );
  }
}
