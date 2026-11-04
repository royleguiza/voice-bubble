import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

import '../helpers/mock_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
  });

  tearDown(unregisterAppChannelMocks);

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
    testWidgets('abre en Notas: título grande con la key estable', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('homeTitleText'))).data,
        'Notas',
      );
      // Sin AppBar: el título grande se desplaza con la lista.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('muestra el botón de Ajustes', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('homeSettingsButton')), findsOneWidget);
    });

    testWidgets('shows RecordButton widget', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recordButton')), findsOneWidget);
    });

    testWidgets('la línea de estado existe y en reposo no dice nada', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('homeStatusText')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('homeStatusText'))).data,
        isEmpty,
      );
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

      await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-transcripcion')), findsOneWidget);
    });

    testWidgets('tapping record button changes to recording state', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      // La pastilla anima el pulso y la onda: pump fijo, no settle.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('el selector cambia a Historial y el título lo acompaña',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-tab-historial')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('homeTitleText'))).data,
        'Historial',
      );
      expect(find.byKey(const ValueKey('history-empty-message')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-tab-notas')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('homeTitleText'))).data,
        'Notas',
      );
    });

    testWidgets('sin notas muestra la bienvenida, no una lista vacía',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notesEmpty')), findsOneWidget);
    });

    testWidgets('✕ en la pastilla descarta: vuelve a reposo sin transcribir',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('recordPill')), findsOneWidget);
      // El ✕ se destapa recién con la pastilla abierta (morph de 350 ms).
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const ValueKey('recordCancelButton')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);
      expect(find.byKey(const ValueKey('recordProcessing')), findsNothing);
    });

    testWidgets('shows stop icon when recording and tapped again', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      // La pastilla anima el pulso y la onda: pump fijo, no settle.
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

  /// Fondo y vuelta por la secuencia real de Android. Saltar de paused a
  /// resumed directo lo rechaza el AppLifecycleListener del buscador.
  void cycleBackgroundAndBack(WidgetTester tester) {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  group('Refresco del historial al volver a la app', () {
    testWidgets(
        'un dictado escrito por el teclado en segundo plano aparece tras resumed',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Estado inicial: historial vacio.
      await tester.tap(find.byKey(const ValueKey('home-tab-historial')));
      await tester.pumpAndSettle();
      expect(find.text('No hay transcripciones aun'), findsOneWidget);

      // Simular la escritura externa del teclado en SharedPreferences
      // mientras la app esta de fondo.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('transcriptions', [
        jsonEncode({
          'text': 'dictado externo del teclado',
          'timestamp':
              DateTime.parse('2026-08-23T10:00:00Z').toIso8601String(),
        }),
      ]);

      // Ciclo de vida paused -> resumed: dispara didChangeAppLifecycleState.
      cycleBackgroundAndBack(tester);
      await tester.pumpAndSettle();

      // El nuevo dictado aparece en la pestaña sin reiniciar la app.

      expect(find.textContaining('dictado externo del teclado'),
          findsOneWidget);
      expect(find.text('No hay transcripciones aun'), findsNothing);
    });

    testWidgets('resumed sin escrituras previas mantiene la pantalla estable',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      cycleBackgroundAndBack(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
      expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-tab-historial')));
      await tester.pumpAndSettle();
      expect(find.text('No hay transcripciones aun'), findsOneWidget);
    });
  });
}
