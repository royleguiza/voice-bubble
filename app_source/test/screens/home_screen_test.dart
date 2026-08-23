import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    // Canales reales del paquete record 5.x (llfbandit)
    for (final channel in [
      'com.llfbandit.record',
      'com.llfbandit.record/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall methodCall) async {
          final m = methodCall.method.toLowerCase();
          if (m.contains('permission')) {
            return true;
          }
          switch (methodCall.method) {
            case 'start':
            case 'create':
            case 'dispose':
            case 'pause':
            case 'resume':
            case 'cancel':
              return null;
            case 'stop':
              return '/tmp/recording.m4a';
            case 'isRecording':
            case 'is_recording':
              return true;
            case 'isPaused':
            case 'is_paused':
              return false;
            case 'getAmplitude':
              return {'current': -160.0, 'max': -160.0};
            case 'listInputDevices':
              return <Map<String, dynamic>>[];
            default:
              return true;
          }
        },
      );
    }

    // Exclusion mutua K3: teclado libre en estos flujos.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.royleguiza.voicebubblestt/keyboard'),
      (MethodCall call) async => false,
    );

    for (final channel in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall methodCall) async => '/tmp',
      );
    }

    for (final channel in [
      'com.royleguiza.voicebubblestt/floating_bubble',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall methodCall) async => true,
      );
    }
  });

  tearDown(() {
    for (final channel in [
      'com.royleguiza.voicebubblestt/floating_bubble',
      'com.llfbandit.record',
      'com.llfbandit.record/messages',
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
      'plugins.it_nomads.com/flutter_secure_storage',
      'plugins.flutter.io/shared_preferences',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  Widget buildTestableWidget({
    TranscriptionService? transcriptionService,
    StorageService? storageService,
  }) {
    return MaterialApp(
      home: HomeScreen(
        transcriptionService: transcriptionService,
        storageService: storageService,
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('renders AppBar with "VoiceBubble STT" title', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows settings icon in AppBar', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows RecordButton widget', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recordButton')), findsOneWidget);
    });

    testWidgets('shows "Listo para transcribir" text initially', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Listo para transcribir'), findsOneWidget);
    });

    testWidgets('shows mic icon in record button initially', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('settings button navigates to SettingsScreen', (tester) async {
      // Superficie alta: la pagina de Settings es mas larga que el viewport
      // por defecto y el ListView lazy no construye lo que queda fuera
      // (9.1-17); la seccion de snippets la alargo aun mas (9.1-21).
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('API Key de Groq'), findsOneWidget);
    });

    testWidgets('tapping record button changes to recording state', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      // El anillo pulsante es infinito: pump fijo, no settle.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('AppBar title is centered', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, isTrue);
    });

    testWidgets('shows stop icon when recording and tapped again', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      // El anillo pulsante es infinito: pump fijo, no settle.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('floating bubble tap triggers recording start and state updates',
        (tester) async {
      final bubbleService = FloatingBubbleService();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          floatingBubbleService: bubbleService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Simulate native bubble tap
      bubbleService.onBubbleTap?.call();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('floating bubble close updates preference in storage',
        (tester) async {
      final storage = StorageService();
      await storage.saveFloatingBubbleEnabled(true);
      final bubbleService = FloatingBubbleService();

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          storageService: storage,
          floatingBubbleService: bubbleService,
        ),
      ));
      await tester.pumpAndSettle();

      bubbleService.onBubbleClose?.call();
      await tester.pumpAndSettle();

      expect(await storage.loadFloatingBubbleEnabled(), isFalse);
    });
  });

  group('Refresco del historial al volver a la app', () {
    testWidgets(
        'un dictado escrito por el teclado en segundo plano aparece tras resumed',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Estado inicial: historial vacio.
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('No hay transcripciones aun'), findsOneWidget);

      // Cerrar el sheet para reabrirlo despues del ciclo de vida.
      final sheetContext =
          tester.element(find.text('No hay transcripciones aun'));
      Navigator.of(sheetContext).pop();
      await tester.pumpAndSettle();

      // Simular la escritura externa del teclado en SharedPreferences
      // mientras la app esta de fondo.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('transcriptions', [
        jsonEncode({
          'text': 'dictado externo del teclado',
          'timestamp':
              DateTime.parse('2026-08-23T10:00:00Z').toIso8601String(),
          'isLocal': false,
        }),
      ]);

      // Ciclo de vida paused -> resumed: dispara didChangeAppLifecycleState.
      addTearDown(() {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // El nuevo dictado debe verse al abrir el historial.
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(find.textContaining('dictado externo del teclado'),
          findsOneWidget);
      expect(find.text('No hay transcripciones aun'), findsNothing);
    });

    testWidgets('resumed sin escrituras previas mantiene la pantalla estable',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      addTearDown(() {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT'), findsOneWidget);
      expect(find.text('Listo para transcribir'), findsOneWidget);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('No hay transcripciones aun'), findsOneWidget);
    });
  });
}
