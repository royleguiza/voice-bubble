import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

import '../helpers/wav_fixture.dart';
import '../helpers/mock_channels.dart';

/// C-42: integridad del WAV antes de subir + multipart explícito.
///
/// Un truncado/garbage pasaba los chequeos de tamaño y Groq lo rechazaba
/// con 400 "valid media file". Ahora se valida la cabecera en cliente y
/// el parte lleva filename audio.wav + audio/wav como el nativo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSttService.isValidWavHeader', () {
    test('acepta cabecera PCM16 mono 16k bien formada', () {
      final bytes = validWavBytes();
      expect(CloudSttService.isValidWavHeader(bytes, bytes.length), isTrue);
    });

    test('rechaza archivo corto', () {
      expect(CloudSttService.isValidWavHeader(<int>[1, 2, 3], 3), isFalse);
      expect(CloudSttService.isValidWavHeader(validWavBytes().sublist(0, 43), 43), isFalse);
    });

    test('rechaza magias rotas', () {
      final good = validWavBytes();
      for (final off in <int>[0, 8, 12, 36]) {
        final bad = List<int>.from(good);
        bad[off] = 0x58;
        expect(
          CloudSttService.isValidWavHeader(bad, bad.length),
          isFalse,
          reason: 'offset $off',
        );
      }
    });

    test('rechaza dataSize cero o mayor que el archivo', () {
      final good = validWavBytes();
      final zero = List<int>.from(good);
      zero[40] = 0;
      zero[41] = 0;
      zero[42] = 0;
      zero[43] = 0;
      expect(CloudSttService.isValidWavHeader(zero, zero.length), isFalse);

      final huge = List<int>.from(good);
      huge[40] = 0xFF;
      huge[41] = 0xFF;
      huge[42] = 0xFF;
      huge[43] = 0x7F;
      expect(CloudSttService.isValidWavHeader(huge, huge.length), isFalse);
    });

    test('rechaza RIFF que declara más de lo que hay', () {
      final good = validWavBytes();
      final bad = List<int>.from(good);
      bad[4] = 0xFF;
      bad[5] = 0xFF;
      bad[6] = 0xFF;
      bad[7] = 0x7F;
      expect(CloudSttService.isValidWavHeader(bad, bad.length), isFalse);
    });

    test('tolera chunks extra (JUNK) antes de data', () {
      final good = validWavBytes(4096);
      final head36 = good.sublist(0, 36);
      final rest = good.sublist(36);
      final List<int> junk = <int>[
        0x4A, 0x55, 0x4E, 0x4B, // JUNK
        0x08, 0x00, 0x00, 0x00, // size 8
        0, 0, 0, 0, 0, 0, 0, 0,
      ];
      final withJunk = head36 + junk + rest;
      final int fileLength = withJunk.length;
      final int riff = fileLength - 8;
      withJunk[4] = riff & 0xFF;
      withJunk[5] = (riff >> 8) & 0xFF;
      withJunk[6] = (riff >> 16) & 0xFF;
      withJunk[7] = (riff >> 24) & 0xFF;
      expect(
          CloudSttService.isValidWavHeader(withJunk, fileLength), isTrue);
    });

    test('rechaza fmt sin data (recorte a mitad de chunks)', () {
      final good = validWavBytes();
      final cut = good.sublist(0, 60);
      expect(CloudSttService.isValidWavHeader(cut, cut.length), isFalse);
    });

    test('informa el motivo entre códigos conocidos', () {
      expect(CloudSttService.checkWavHeader(<int>[1, 2], 2), 'corto');
      final good = validWavBytes();
      expect(
          CloudSttService.checkWavHeader(good, good.length), 'ok');
      final noRiff = List<int>.from(good);
      noRiff[0] = 0x58;
      expect(CloudSttService.checkWavHeader(noRiff, noRiff.length),
          'no-riff');
      final empty = List<int>.from(good);
      empty[40] = 0;
      empty[41] = 0;
      empty[42] = 0;
      empty[43] = 0;
      expect(
          CloudSttService.checkWavHeader(empty, empty.length), 'vacio');
    });
  });

  group('CloudSttService.transcribe - integridad (C-42)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wav_integrity_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('no sube audio corrupto (cero llamadas HTTP)', () async {
      final bad = File('${tempDir.path}/roto.wav');
      await bad.writeAsBytes(List<int>.filled(9000, 0x61));
      var calls = 0;
      final service = CloudSttService(
        apiKey: 'gsk_test_key',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"text":"x"}', 200);
        }),
      );
      await expectLater(
        service.transcribe(bad.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            contains('dañado'),
          ),
        ),
      );
      expect(calls, 0);
    });

    test('el parte lleva filename audio.wav y audio/wav', () async {
      final ok = File('${tempDir.path}/nota.wav');
      await ok.writeAsBytes(validWavBytes());
      http.BaseRequest? seen;
      final service = CloudSttService(
        apiKey: 'gsk_test_key',
        client: MockClient((http.BaseRequest request) async {
          seen = request;
          return http.Response('{"text":"hola"}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final result = await service.transcribe(ok.path);
      expect(result.text, 'hola');
      // MockClient finaliza el multipart: se verifica sobre los bytes
      // (el cuerpo binario no decodifica como UTF-8 estricto).
      final req = seen! as http.Request;
      final String bodyText =
          utf8.decode(req.bodyBytes, allowMalformed: true);
      expect(bodyText, contains('filename="audio.wav"'));
      expect(bodyText, contains('audio/wav'));
      expect(bodyText, contains('whisper-large-v3-turbo'));
      expect(bodyText, contains('name="language"'));
    });
  });

  group('TranscriptionService.transcribe - vuelo único (C-43)', () {
    test('segundo intento concurrente recibe ocupado', () async {
      SharedPreferences.setMockInitialValues({});
      final dir =
          await Directory.systemTemp.createTemp('singleflight_test_');
      registerAppChannelMocks(temporaryDirectory: dir.path);
      try {
        final a = File('${dir.path}/a.wav');
        await a.writeAsBytes(validWavBytes());
        final gate = Completer<http.Response>();
        final service = TranscriptionService(
          cloudService: CloudSttService(
            apiKey: 'gsk_test_key',
            client: MockClient((_) => gate.future),
          ),
          storageService: StorageService(),
          recorder: _StillRecorder(),
          claimMicrophone: () async => 1,
          releaseMicrophone: (_) async {},
        );
        final first =
            service.transcribe(a.path, deleteAudioOnSuccess: false);
        await expectLater(
          service.transcribe(a.path),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'message',
              contains('en curso'),
            ),
          ),
        );
        gate.complete(http.Response('{"text":"hola"}', 200,
            headers: {'content-type': 'application/json'}));
        expect((await first).text, 'hola');
      } finally {
        unregisterAppChannelMocks();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    });
  });
}

class _StillRecorder implements AudioRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
