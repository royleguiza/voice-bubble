import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/main.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    for (final channel in [
      'com.llcgram.record',
      'com.llcgram.record/messages',
      'com.llcgram.record/events',
      'com.llcgram.record_android',
      'com.llcgram.record_linux',
      'com.llcgram.record_windows',
      'com.llcgram.record_darwin',
      'com.llcgram.record_web',
      'net.chemirea.record',
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

    for (final channel in [
      'plugin.speech_to_text',
      'plugin.speech_to_text.android',
      'plugin.speech_to_text.ios',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'initialize':
            case 'hasPermission':
              return true;
            case 'listen':
            case 'stop':
            case 'cancel':
              return null;
            default:
              return null;
          }
        },
      );
    }
  });

  tearDown(() {
    for (final channel in [
      'com.llcgram.record',
      'com.llcgram.record/messages',
      'com.llcgram.record/events',
      'com.llcgram.record_android',
      'com.llcgram.record_linux',
      'com.llcgram.record_windows',
      'com.llcgram.record_darwin',
      'com.llcgram.record_web',
      'net.chemirea.record',
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
      'plugin.speech_to_text',
      'plugin.speech_to_text.android',
      'plugin.speech_to_text.ios',
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
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verificación: estado grabando activo
      expect(find.text('Grabando...'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      // 3. Detener grabación: segundo tap alterna a detener
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verificación: grabación detenida, vuelve al estado inicial
      expect(find.text('Grabando...'), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('La app muestra selector de modo y permite alternar entre Cloud y Local', (tester) async {
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();

      // Modo por defecto es Cloud
      final segmentedButton = tester.widget<SegmentedButton<TranscriptionMode>>(
        find.byType(SegmentedButton<TranscriptionMode>),
      );
      expect(segmentedButton.selected, contains(TranscriptionMode.cloud));

      // Alternar a Local
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      final segmentedButtonLocal = tester.widget<SegmentedButton<TranscriptionMode>>(
        find.byType(SegmentedButton<TranscriptionMode>),
      );
      expect(segmentedButtonLocal.selected, contains(TranscriptionMode.local));

      // Alternar de vuelta a Cloud
      await tester.tap(find.text('Cloud'));
      await tester.pumpAndSettle();

      final segmentedButtonCloud = tester.widget<SegmentedButton<TranscriptionMode>>(
        find.byType(SegmentedButton<TranscriptionMode>),
      );
      expect(segmentedButtonCloud.selected, contains(TranscriptionMode.cloud));
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
