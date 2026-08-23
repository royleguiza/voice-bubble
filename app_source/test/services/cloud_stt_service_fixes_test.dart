import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';

/// Comportamiento REAL de CloudSttService contra un cliente HTTP simulado.
/// Cada test puede fallar ante una regresion del servicio; los antiguos
/// grupos que probaban jsonDecode/literales se eliminaron (AT-D2).
void main() {
  late Directory tempDir;
  late File tempAudioFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stt_fixes_test_');
    tempAudioFile = File('${tempDir.path}/test_audio.wav');
    await tempAudioFile.writeAsBytes(List<int>.filled(1024, 0));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Clasificacion de errores de red del servicio', () {
    test('servicio lanza TranscriptionException al recibir SocketException',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const SocketException('Connection failed');
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

    test('servicio lanza TranscriptionException al recibir ClientException',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw http.ClientException('Connection reset');
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

    test('servicio lanza TranscriptionException al recibir HttpException',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const HttpException('Connection closed');
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

    test('servicio lanza TranscriptionException al recibir HandshakeException',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const HandshakeException('Handshake error');
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

    test('servicio lanza TranscriptionException al recibir TlsException',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw const TlsException('TLS error');
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

    test('servicio lanza TranscriptionException al ocurrir TimeoutException',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        throw TimeoutException('Request timeout');
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

  group('Manejo de errores HTTP del servicio', () {
    test(
        'servicio lanza TranscriptionException con mensaje de API key inválida al recibir 401',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Invalid API Key"}')),
          401,
        );
      });
      final service =
          CloudSttService(apiKey: 'invalid-key', client: mockClient);
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

    test(
        'servicio lanza TranscriptionException con mensaje de rate limit al recibir 429',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Rate limit exceeded"}')),
          429,
        );
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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

    test('servicio lanza TranscriptionException al recibir error 500',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "Internal Server Error"}')),
          500,
        );
      });
      final service = CloudSttService(apiKey: 'test-key', client: mockClient);
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
  });

  group('Validaciones previas al request', () {
    test('servicio lanza error si API key está vacía', () async {
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

    test('servicio lanza error si archivo de audio no existe', () async {
      const service = CloudSttService(apiKey: 'test-key');
      await expectLater(
        service.transcribe('/nonexistent/audio.wav'),
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

  group('Request multipart y parseo de respuesta', () {
    test(
        'con API key y archivo válidos envía el request a Groq con Bearer y retorna transcripción',
        () async {
      var requestSent = false;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        requestSent = true;
        expect(request.url.toString(),
            'https://api.groq.com/openai/v1/audio/transcriptions');
        expect(request.headers['Authorization'], 'Bearer valid-key');
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"text": "Transcripción completada"}')),
          200,
        );
      });

      final service =
          CloudSttService(apiKey: 'valid-key', client: mockClient);
      final result = await service.transcribe(tempAudioFile.path);

      expect(requestSent, isTrue);
      expect(result.text, 'Transcripción completada');
      expect(result.timestamp, isA<DateTime>());
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
