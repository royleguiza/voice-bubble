import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';

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

  Widget buildTestApp({Widget? home}) {
    return MaterialApp(
      home: home ?? const HomeScreen(),
    );
  }

  group('Full user flow – VoiceBubble STT', () {
    testWidgets(
      '1. App launches and shows HomeScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('VoiceBubble STT'), findsOneWidget);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      '2. Settings button opens SettingsScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Configuración'), findsOneWidget);
      },
    );

    testWidgets(
      '3. SettingsScreen shows API key input',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp(home: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('API Key de Groq'), findsOneWidget);
        expect(find.text('gsk_...'), findsOneWidget);
      },
    );

    testWidgets(
      '4. User can enter and save API key',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp(home: const SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'gsk_test_key_123');
        await tester.pumpAndSettle();

        expect(find.text('gsk_test_key_123'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        expect(find.text('API key guardada'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Back button returns to HomeScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      '6. Record button shows recording state',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        expect(find.text('Listo para transcribir'), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(find.text('Grabando...'), findsOneWidget);
      },
    );

    testWidgets(
      '10. Transcription model can be created and serialized',
      (WidgetTester tester) async {
        final timestamp = DateTime(2025, 7, 15, 10, 30, 0);
        final transcription = Transcription(
          text: 'Hola mundo',
          timestamp: timestamp,
          isLocal: false,
        );

        expect(transcription.text, 'Hola mundo');
        expect(transcription.timestamp, timestamp);
        expect(transcription.isLocal, false);

        final json = transcription.toJson();
        expect(json['text'], 'Hola mundo');
        expect(json['isLocal'], false);
        expect(json['timestamp'], timestamp.toIso8601String());

        final restored = Transcription.fromJson(json);
        expect(restored, transcription);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });

  group('SettingsScreen navigation round-trip', () {
    testWidgets(
      'Home → Settings → Back preserves state',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'gsk_round_trip');
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();
        expect(find.text('API key guardada'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );
  });

  group('Transcription model edge cases', () {
    test('equality operator with same values', () {
      final t1 = Transcription(
        text: 'test',
        timestamp: DateTime(2025),
        isLocal: true,
      );
      final t2 = Transcription(
        text: 'test',
        timestamp: DateTime(2025),
        isLocal: true,
      );
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('inequality with different text', () {
      final t1 = Transcription(
        text: 'hello',
        timestamp: DateTime(2025),
        isLocal: true,
      );
      final t2 = Transcription(
        text: 'world',
        timestamp: DateTime(2025),
        isLocal: true,
      );
      expect(t1, isNot(equals(t2)));
    });

    test('inequality with different isLocal', () {
      final t1 = Transcription(
        text: 'test',
        timestamp: DateTime(2025),
        isLocal: true,
      );
      final t2 = Transcription(
        text: 'test',
        timestamp: DateTime(2025),
        isLocal: false,
      );
      expect(t1, isNot(equals(t2)));
    });

    test('serialization round-trip with special characters', () {
      final t = Transcription(
        text: 'Acentos: áéíóú ñ, emoji: 🎤',
        timestamp: DateTime(2025, 12, 31, 23, 59, 59),
        isLocal: true,
      );
      final restored = Transcription.fromJson(t.toJson());
      expect(restored, equals(t));
      expect(restored.text, 'Acentos: áéíóú ñ, emoji: 🎤');
    });
  });
}
