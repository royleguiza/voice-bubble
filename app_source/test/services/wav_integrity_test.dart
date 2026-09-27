import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';

import '../helpers/wav_fixture.dart';

/// C-42: integridad del WAV antes de subir + multipart explícito.
///
/// Un truncado/garbage pasaba los chequeos de tamaño y Groq lo rechazaba
/// con 400 "valid media file". Ahora se valida la cabecera en cliente y
/// el parte lleva filename audio.wav + audio/wav como el nativo.
void main() {
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
      final multi = seen! as http.MultipartRequest;
      expect(multi.fields['model'], 'whisper-large-v3-turbo');
      expect(multi.fields['language'], 'es');
      expect(multi.files, hasLength(1));
      expect(multi.files.single.filename, 'audio.wav');
      expect(multi.files.single.contentType.mimeType, 'audio/wav');
    });
  });
}
