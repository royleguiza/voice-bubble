/// Mocks unicos de canales de plataforma para los tests que montan la app
/// completa (widget_test, home_screen_test, full_flow_test).
///
/// record 7.x: el CONSTRUCTOR de AudioRecorder() ya invoca 'create' al canal
/// (leccion 11), por eso ambos canales llfbandit se mockean siempre, aunque
/// el recorder se inyecte.
///
/// La grabacion simulada termina en un path .wav: es la extension del
/// contenedor que produce AudioEncoder.wav (leccion 13) y la que Groq valida.
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _recordChannels = [
  'com.llfbandit.record',
  'com.llfbandit.record/messages',
];

const List<String> _pathProviderChannels = [
  'plugins.flutter.io/path_provider',
  'plugins.flutter.io/path_provider_android',
  'plugins.flutter.io/path_provider_ios',
  'plugins.flutter.io/path_provider_macos',
  'plugins.flutter.io/path_provider_linux',
  'plugins.flutter.io/path_provider_windows',
];

const String _floatingBubbleChannel =
    'com.royleguiza.voicebubblestt/floating_bubble';
const String _keyboardChannel = 'com.royleguiza.voicebubblestt/keyboard';

/// Canales que [registerAppChannelMocks] deja mockeados; los tests lo usan
/// en tearDown para restaurar el messenger.
final List<String> appMockedChannels = [
  ..._recordChannels,
  ..._pathProviderChannels,
  _floatingBubbleChannel,
  _keyboardChannel,
];

void registerAppChannelMocks({String temporaryDirectory = '/tmp'}) {
  try {
    final file = File('$temporaryDirectory/transcription_history.json');
    // Sync a propósito: setup de tests con archivos reales (la regla
    // avoid_slow_async_io solo observa métodos async, no estos).
    if (file.existsSync()) file.deleteSync();
    final tmp = File('$temporaryDirectory/transcription_history.json.tmp');
    if (tmp.existsSync()) tmp.deleteSync();
  } catch (_) {}

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final channel in _recordChannels) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (MethodCall call) async {
        if (call.method.toLowerCase().contains('permission')) return true;
        switch (call.method) {
          case 'start':
          case 'create':
          case 'dispose':
          case 'pause':
          case 'resume':
          case 'cancel':
            return null;
          case 'stop':
            return '$temporaryDirectory/recording.wav';
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

  for (final channel in _pathProviderChannels) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (MethodCall call) async => temporaryDirectory,
    );
  }

  messenger.setMockMethodCallHandler(
    const MethodChannel(_floatingBubbleChannel),
    (MethodCall call) async => true,
  );

  // Exclusion mutua K3: teclado libre en estos flujos.
  messenger.setMockMethodCallHandler(
    const MethodChannel(_keyboardChannel),
    (MethodCall call) async =>
        call.method == 'isKeyboardRecording' ? false : true,
  );
}

void unregisterAppChannelMocks() {
  try {
    final file = File('/tmp/transcription_history.json');
    // Sync a propósito en teardown (ver arriba).
    if (file.existsSync()) file.deleteSync();
    final tmp = File('/tmp/transcription_history.json.tmp');
    if (tmp.existsSync()) tmp.deleteSync();
  } catch (_) {}

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in appMockedChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), null);
  }
}

/// Solo los dos canales del plugin record 7.x, con el handler canónico
/// (el mismo de [registerAppChannelMocks]): permiso concedido, 'create' /
/// 'start' sin efecto, 'stop' devuelve un .wav, etc.
///
/// Para tests de servicio que NO montan la app (recording_design,
/// mic_exclusion): conserva su setUp/tearDown propio sin arrastrar los
/// canales de path_provider/burbuja/teclado.
void registerRecordChannelMocks({String temporaryDirectory = '/tmp'}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final channel in _recordChannels) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (MethodCall call) async {
        if (call.method.toLowerCase().contains('permission')) return true;
        switch (call.method) {
          case 'start':
          case 'create':
          case 'dispose':
          case 'pause':
          case 'resume':
          case 'cancel':
            return null;
          case 'stop':
            return '$temporaryDirectory/recording.wav';
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
}

/// Libera solo los canales registrados por [registerRecordChannelMocks].
void unregisterRecordChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in _recordChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), null);
  }
}
