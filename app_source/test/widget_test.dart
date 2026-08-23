import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/main.dart';

import 'helpers/mock_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
  });

  tearDown(unregisterAppChannelMocks);

  group('VoiceBubbleApp Widget Tests', () {
    testWidgets('La app abre y alterna estado de grabación', (tester) async {
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();

      // Estado inicial: texto de bienvenida y botón con icono de micrófono
      expect(find.text('Listo para transcribir'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);

      // Iniciar grabación: tap en el botón de grabar
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));

      // Verificación: estado grabando activo
      expect(find.text('Grabando...'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      // Detener grabación: segundo tap alterna a detener
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Verificación: grabación detenida, vuelve al estado inicial
      expect(find.text('Grabando...'), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('La app navega a Configuración y permite volver a la pantalla principal', (tester) async {
      // Superficie alta: la pagina de Settings es mas larga que el viewport
      // por defecto y el ListView lazy no construye lo que queda fuera
      // (9.1-17); la seccion de snippets la alargo aun mas (9.1-21).
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();

      // Navegar a Configuración
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('API Key de Groq'), findsOneWidget);

      // Volver a Home
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT'), findsOneWidget);
      expect(find.text('Listo para transcribir'), findsOneWidget);
    });
  });
}
