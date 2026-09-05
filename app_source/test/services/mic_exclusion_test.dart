import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

import '../helpers/mock_channels.dart';

/// Exclusion mutua de microfono burbuja<->teclado (K3, tarea 6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // Canales del plugin record 7.x: permiso concedido y start sin efecto,
    // para que el camino feliz de startRecording complete en tests.
    // Handler canónico compartido (helpers/mock_channels.dart).
    registerRecordChannelMocks();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record'), null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'), null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.royleguiza.voicebubblestt/keyboard'), null);
  });

  TranscriptionService buildService({MicBlockedProbe? isMicBlocked}) {
    return TranscriptionService(
      cloudService: const CloudSttService(apiKey: 'k'),
      storageService: StorageService(),
      recorder: AudioRecorder(),
      isMicBlocked: isMicBlocked,
    );
  }

  group('Exclusion mutua de microfono', () {
    test('bloquea el inicio cuando el teclado esta grabando', () async {
      var probeConsultas = 0;
      final service = buildService(isMicBlocked: () async {
        probeConsultas++;
        return true;
      });

      await expectLater(
        service.startRecording('/tmp/no-debe-llegar.wav'),
        throwsA(isA<TranscriptionException>()),
      );
      expect(probeConsultas, 1);
    });

    test('el error de ocupacion es descriptivo', () async {
      final service = buildService(isMicBlocked: () async => true);

      await expectLater(
        service.startRecording('/tmp/x.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            contains('teclado'),
          ),
        ),
      );
    });

    test('permite grabar cuando el teclado esta libre', () async {
      final service = buildService(isMicBlocked: () async => false);

      await service.startRecording('/tmp/libre.wav');
      await service.stopRecording();
    });

    test('sonda por defecto responde false sin canal nativo (defensivo)',
        () async {
      // Sin handler registrado para el canal del teclado:
      // MissingPluginException se traga y devuelve false.
      final service = buildService();
      await service.startRecording('/tmp/default-probe.wav');
      await service.stopRecording();
    });
  });
}
