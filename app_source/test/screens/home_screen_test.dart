import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
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
            default:
              return null;
          }
        },
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
      // El anillo pulsante es infinito: pump fijo, no settle.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

  });
}
