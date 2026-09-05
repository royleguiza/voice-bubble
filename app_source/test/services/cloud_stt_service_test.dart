import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';

void main() {
  late Directory tempDir;
  late File tempAudioFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloud_stt_test_');
    tempAudioFile = File('${tempDir.path}/test_audio.wav');
    await tempAudioFile.writeAsBytes(List<int>.filled(1024, 0));
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
}
