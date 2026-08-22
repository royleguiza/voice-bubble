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

  group('TranscriptionException', () {
    test('stores message correctly', () {
      const exception = TranscriptionException('test message');
      expect(exception.message, 'test message');
    });

    test('toString returns the message', () {
      const exception = TranscriptionException('something went wrong');
      expect(exception.toString(), 'something went wrong');
    });

    test('handles empty message', () {
      const exception = TranscriptionException('');
      expect(exception.message, '');
      expect(exception.toString(), '');
    });

    test('handles message with special characters', () {
      const exception = TranscriptionException('Error: API key inválida (401)');
      expect(exception.message, 'Error: API key inválida (401)');
      expect(exception.toString(), 'Error: API key inválida (401)');
    });

    test('handles long message', () {
      final longMessage = 'A' * 500;
      final exception = TranscriptionException(longMessage);
      expect(exception.message, longMessage);
      expect(exception.toString(), longMessage);
    });
  });

  group('CloudSttService constructor', () {
    test('stores apiKey correctly', () {
      const service = CloudSttService(apiKey: 'my-secret-key');
      expect(service.apiKey, 'my-secret-key');
    });

    test('stores different apiKey values', () {
      const service1 = CloudSttService(apiKey: 'key-one');
      const service2 = CloudSttService(apiKey: 'key-two');
      expect(service1.apiKey, 'key-one');
      expect(service2.apiKey, 'key-two');
    });

    test('handles apiKey with special characters', () {
      const service =
          CloudSttService(apiKey: 'gsk_abc123!@#\$%^&*()_+-=');
      expect(service.apiKey, 'gsk_abc123!@#\$%^&*()_+-=');
    });

    test('handles apiKey with spaces', () {
      const service = CloudSttService(apiKey: 'key with spaces');
      expect(service.apiKey, 'key with spaces');
    });

    test('handles empty apiKey in constructor', () {
      const service = CloudSttService(apiKey: '');
      expect(service.apiKey, '');
    });

    test('handles very long apiKey', () {
      final longKey = 'k' * 1000;
      final service = CloudSttService(apiKey: longKey);
      expect(service.apiKey, longKey);
    });

    test('stores custom client correctly', () {
      final customClient = MockClient((request) async => http.Response('{}', 200));
      final service = CloudSttService(apiKey: 'key', client: customClient);
      expect(service.client, same(customClient));
    });
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
    test('retorna Transcription exitosa con status 200', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"text": "Transcripción completada con éxito"}')),
          200,
        );
      });

      final service = CloudSttService(apiKey: 'valid-key', client: mockClient);
      final result = await service.transcribe(tempAudioFile.path);

      expect(result.text, 'Transcripción completada con éxito');
      expect(result.isLocal, isFalse);
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

  group('CloudSttService constants', () {
    test('is a const constructible class', () {
      const service = CloudSttService(apiKey: 'test');
      expect(service.apiKey, 'test');
    });
  });
}
