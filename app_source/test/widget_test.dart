import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
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

  });

  tearDown(() {
    for (final channel in [
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

  group('VoiceBubbleApp Widget Tests', () {
    testWidgets('La app abre y alterna estado de grabación', (tester) async {
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();

      // 1. Estado inicial: texto de bienvenida y botón con icono de micrófono
      expect(find.text('Listo para transcribir'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);

      // 2. Iniciar grabación: tap en el botón de grabar
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));

      // Verificación: estado grabando activo
      expect(find.text('Grabando...'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      // 3. Detener grabación: segundo tap alterna a detener
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));

      // Verificación: grabación detenida, vuelve al estado inicial
      expect(find.text('Grabando...'), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('La app navega a Configuración y permite volver a la pantalla principal', (tester) async {
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
