import 'dart:ui' show Locale;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/ui/app_locale.dart';

import '../helpers/wav_fixture.dart';

void main() {
  late Directory tempDir;
  late File tempAudioFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloud_stt_test_');
    tempAudioFile = File('${tempDir.path}/test_audio.wav');
    await tempAudioFile.writeAsBytes(validWavBytes());
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CloudSttService.transcribe - validación de parámetros', () {
    test('empty API key throws TranscriptionException', () async {
      const service = CloudSttService(apiKey: '');
      await expectLater(
        service.transcribe('/any/path.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'API key de Groq no configurada. Ve a Settings para agregarla.',
          ),
        ),
      );
    });

    test('whitespace-only API key is not considered empty', () async {
      const service = CloudSttService(apiKey: '   ');
      await expectLater(
        service.transcribe('/nonexistent/path.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Archivo de audio no encontrado.',
          ),
        ),
      );
    });

    test('non-existent audio file throws TranscriptionException', () async {
      const service = CloudSttService(apiKey: 'valid-key-123');
      await expectLater(
        service.transcribe('/definitely/does/not/exist.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Archivo de audio no encontrado.',
          ),
        ),
      );
    });

    test('non-existent file with different path throws TranscriptionException',
        () async {
      const service = CloudSttService(apiKey: 'key');
      await expectLater(
        service.transcribe('/tmp/missing_audio.mp3'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Archivo de audio no encontrado.',
          ),
        ),
      );
    });

    test('empty path throws TranscriptionException for missing file', () async {
      const service = CloudSttService(apiKey: 'key');
      await expectLater(
        service.transcribe(''),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Archivo de audio no encontrado.',
          ),
        ),
      );
    });
  });

  group('CloudSttService.transcribe - llamadas HTTP simuladas', () {
    test('retorna Transcription exitosa con status 200 (Bearer + endpoint Groq)', () async {
      var requestSent = false;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        requestSent = true;
        expect(request.url.toString(),
            'https://api.groq.com/openai/v1/audio/transcriptions');
        expect(request.headers['Authorization'], 'Bearer valid-key');
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"text": "Transcripción completada con éxito"}')),
          200,
        );
      });

      final service = CloudSttService(apiKey: 'valid-key', client: mockClient);
      final result = await service.transcribe(tempAudioFile.path);

      expect(requestSent, isTrue);
      expect(result.text, 'Transcripción completada con éxito');
      expect(result.timestamp, isA<DateTime>());
    });

    test('status 401 lanza TranscriptionException con mensaje de API key', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Unauthorized"}')),
          401,
        );
      });

      final service = CloudSttService(apiKey: 'invalid-key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'API key inválida. Verifica tu clave en Settings.',
          ),
        ),
      );
    });

    test('status 429 lanza TranscriptionException con mensaje de rate limit', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Rate limit"}')),
          429,
        );
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.',
          ),
        ),
      );
    });

    test('status 500 lanza TranscriptionException con código de servidor', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Internal Error"}')),
          500,
        );
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Error del servidor Groq (500). Intenta de nuevo.',
          ),
        ),
      );
    });

    test('SocketException lanza TranscriptionException con mensaje de red', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const SocketException('Connection failed');
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Sin conexión a internet.',
          ),
        ),
      );
    });

    test('ClientException lanza TranscriptionException con mensaje de red', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw http.ClientException('Client error');
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Sin conexión a internet.',
          ),
        ),
      );
    });

    test('HttpException lanza TranscriptionException con mensaje de red', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const HttpException('Connection closed');
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Sin conexión a internet.',
          ),
        ),
      );
    });

    test('HandshakeException lanza TranscriptionException con mensaje de red', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const HandshakeException('Handshake error');
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Sin conexión a internet.',
          ),
        ),
      );
    });

    test('TlsException lanza TranscriptionException con mensaje de red', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const TlsException('TLS error');
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Sin conexión a internet.',
          ),
        ),
      );
    });

    test('TimeoutException lanza TranscriptionException con mensaje de timeout', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw TimeoutException('Request timeout');
      });

      final service = CloudSttService(apiKey: 'key', client: mockClient);
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Tiempo de espera agotado al conectar con el servidor.',
          ),
        ),
      );
    });
  });

  group('timeoutForBytes - clamp [60s, 600s]', () {
    test('archivos chicos quedan en el piso de 60 s', () {
      const service = CloudSttService(apiKey: 'k');
      expect(service.timeoutForBytes(0), const Duration(seconds: 60));
      expect(service.timeoutForBytes(49999), const Duration(seconds: 60));
    });

    test('crece 1 s por cada 50 KB completo', () {
      const service = CloudSttService(apiKey: 'k');
      expect(service.timeoutForBytes(50000), const Duration(seconds: 61));
      expect(service.timeoutForBytes(250000), const Duration(seconds: 65));
    });

    test('archivos enormes quedan en el techo de 600 s', () {
      const service = CloudSttService(apiKey: 'k');
      // Justo el umbral del techo.
      expect(service.timeoutForBytes(540 * 50000),
          const Duration(seconds: 600));
      // Por encima del techo.
      expect(service.timeoutForBytes(540 * 50000 + 1),
          const Duration(seconds: 600));
      expect(service.timeoutForBytes(1 << 30), const Duration(seconds: 600));
    });
  });

  group('CloudSttService - modelo elegible (Ruta IA, etapa 1)', () {
    test('turbo por defecto; whisper-large-v3 elegible; lo inválido cae a turbo',
        () {
      expect(CloudSttService.model, 'whisper-large-v3-turbo');
      expect(CloudSttService.preciseModel, 'whisper-large-v3');
      expect(CloudSttService.models,
          ['whisper-large-v3-turbo', 'whisper-large-v3']);
      expect(CloudSttService.normalizeModel('whisper-large-v3'),
          'whisper-large-v3');
      expect(CloudSttService.normalizeModel(' whisper-large-v3-turbo '),
          'whisper-large-v3-turbo');
      for (final raw in [null, '', '   ', 'whisper-1', 'gpt-transcribe']) {
        expect(CloudSttService.normalizeModel(raw), CloudSttService.model,
            reason: 'valor: $raw');
      }
    });

    Future<String> sentModel(CloudSttService base) async {
      String? model;
      final client = MockClient.streaming((request, bodyStream) async {
        final body = latin1.decode(await bodyStream.toBytes());
        final match = RegExp(r'name="model"\r\n\r\n([^\r]+)').firstMatch(body);
        model = match?.group(1);
        return http.StreamedResponse(
            Stream.value(utf8.encode('{"text": "hola"}')), 200);
      });
      await base.copyWith(client: client).transcribe(tempAudioFile.path);
      return model ?? '';
    }

    test('el pedido manda el modelo elegido', () async {
      expect(await sentModel(const CloudSttService(apiKey: 'k')),
          'whisper-large-v3-turbo');
      expect(
          await sentModel(const CloudSttService(
              apiKey: 'k', sttModel: CloudSttService.preciseModel)),
          'whisper-large-v3');
      expect(
          await sentModel(
              const CloudSttService(apiKey: 'k').copyWith(sttModel: 'otro')),
          'whisper-large-v3-turbo');
    });
  });

  group('CloudSttService - idioma en que hablo (Ruta IA, etapa 4)', () {
    test('español por defecto; auto/en/pt elegibles; lo inválido cae a es', () {
      expect(CloudSttService.language, 'es');
      expect(CloudSttService.languages.take(4), ['auto', 'es', 'en', 'pt']);
      // Plan de lanzamiento §10: los idiomas más hablados, cada uno con nombre.
      expect(CloudSttService.languages.length, 17);
      for (final code in CloudSttService.languages.skip(1)) {
        expect(CloudSttService.languageNames[code], isNotNull, reason: code);
      }
      expect(CloudSttService.normalizeLanguage('ja'), 'ja');
      expect(CloudSttService.normalizeLanguage(' en '), 'en');
      expect(CloudSttService.normalizeLanguage('auto'), 'auto');
      appLocale.value = const Locale('es');
      addTearDown(() => appLocale.value = null);
      for (final raw in [null, '', 'xx', 'ES']) {
        expect(CloudSttService.normalizeLanguage(raw), 'es',
            reason: 'valor: $raw');
      }
    });

    test('sin elección, el dictado sigue al idioma de la app (25/11)', () {
      addTearDown(() => appLocale.value = null);
      appLocale.value = const Locale('en');
      expect(CloudSttService.normalizeLanguage(null), 'en');
      appLocale.value = const Locale('pt');
      expect(CloudSttService.normalizeLanguage(null), 'pt');
      // Lo elegido a mano manda siempre.
      expect(CloudSttService.normalizeLanguage('es'), 'es');
      expect(CloudSttService.normalizeLanguage('auto'), 'auto');
    });

    Future<String?> sentLanguage(CloudSttService base) async {
      String? language;
      final client = MockClient.streaming((request, bodyStream) async {
        final body = latin1.decode(await bodyStream.toBytes());
        language = RegExp(r'name="language"\r\n\r\n([^\r]+)')
            .firstMatch(body)
            ?.group(1);
        return http.StreamedResponse(
            Stream.value(utf8.encode('{"text": "hola"}')), 200);
      });
      await base.copyWith(client: client).transcribe(tempAudioFile.path);
      return language;
    }

    test('el pedido manda el idioma elegido y nada en automático', () async {
      expect(await sentLanguage(const CloudSttService(apiKey: 'k')), 'es');
      expect(
          await sentLanguage(
              const CloudSttService(apiKey: 'k', sttLanguage: 'en')),
          'en');
      expect(
          await sentLanguage(const CloudSttService(
              apiKey: 'k', sttLanguage: CloudSttService.autoLanguage)),
          isNull);
    });
  });
}
