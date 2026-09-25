import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

import '../helpers/mock_channels.dart';

class _RecordingMockAudioRecorder implements AudioRecorder {
  RecordConfig? lastConfig;
  String? lastPath;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    lastConfig = config;
    lastPath = path;
  }

  @override
  Future<String?> stop() async => lastPath;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // record 7.x: el constructor de AudioRecorder invoca 'create' en el canal;
  // sin mock lanza MissingPluginException y contamina los tests siguientes.
  // Handler canónico compartido (helpers/mock_channels.dart).
  registerRecordChannelMocks();

  group('Encoder PCM 16 bits (WAV)', () {
    test('startRecording pasa configuración PCM 16 bits mono 16kHz al grabador', () async {
      final mockRecorder = _RecordingMockAudioRecorder();
      final service = TranscriptionService(
        cloudService: const CloudSttService(apiKey: 'test'),
        storageService: StorageService(),
        recorder: mockRecorder,
        claimMicrophone: () async => 1,
        releaseMicrophone: (int claim) async {},
      );

      await service.startRecording('/tmp/test_recording.wav');

      expect(mockRecorder.lastConfig, isNotNull);
      expect(mockRecorder.lastConfig!.encoder, AudioEncoder.wav);
      expect(mockRecorder.lastConfig!.sampleRate, 16000);
      expect(mockRecorder.lastConfig!.numChannels, 1);
      expect(mockRecorder.lastPath, '/tmp/test_recording.wav');
    });
  });

  group('cleanupTempFile', () {
    late TranscriptionService service;
    late Directory tempDir;

    setUp(() {
      service = TranscriptionService(
        cloudService: const CloudSttService(apiKey: 'test'),
        storageService: StorageService(),
      );
      // Sync a propósito: setup/teardown/asserts con directorio real (la
      // regla avoid_slow_async_io solo observa métodos async, no estos).
      tempDir = Directory.systemTemp.createTempSync('voice_bubble_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('elimina el archivo si existe', () async {
      final file = File('${tempDir.path}/test_audio.wav');
      await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);
      expect(file.existsSync(), isTrue);

      await service.cleanupTempFile(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('no lanza excepción si el archivo no existe', () async {
      final fakePath = '${tempDir.path}/no_existe.wav';

      expect(
        () => service.cleanupTempFile(fakePath),
        returnsNormally,
      );
    });

    test('no lanza excepción con ruta vacía', () async {
      expect(
        () => service.cleanupTempFile(''),
        returnsNormally,
      );
    });
  });
}
