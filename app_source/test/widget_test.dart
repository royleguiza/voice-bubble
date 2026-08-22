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

    for (final channel in [
      'com.llcgram.record',
      'com.llcgram.record/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'hasPermission':
            case 'isPermissionGranted':
              return true;
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
              return true;
            default:
              return null;
          }
        },
      );
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '/tmp',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugin.speech_to_text'),
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
  });

  tearDown(() {
    for (final channel in [
      'com.llcgram.record',
      'com.llcgram.record/messages',
      'plugins.flutter.io/path_provider',
      'plugin.speech_to_text',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  testWidgets('La app abre y alterna estado de grabación', (tester) async {
    await tester.pumpWidget(const VoiceBubbleApp());
    await tester.pumpAndSettle();

    expect(find.text('Listo para transcribir'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Grabando...'), findsOneWidget);
  });
}
