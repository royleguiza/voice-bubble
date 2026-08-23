import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';

/// Matriz H5-T5: contrato de clasificacion de errores de CloudSttService.
///
/// Red/timeout y servidor saturado (network/server) = REINTENTABLES.
/// Credenciales o request invalidos (auth/badRequest) = NO reintentables.
/// El servicio NO reintenta por su cuenta: cada llamada transcribe envia
/// exactamente una peticion HTTP, gane o pierda.
void main() {
  late Directory tempDir;
  late File tempAudioFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('h5_errors_test_');
    tempAudioFile = File('${tempDir.path}/audio.wav');
    await tempAudioFile.writeAsBytes(List<int>.filled(2048, 0));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  http.Client clientThrowing(Object error) {
    return MockClient.streaming((request, bodyStream) async {
      throw error;
    });
  }

  http.Client clientResponding(int statusCode, {String body = '{}'}) {
    return MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
    });
  }

  Matcher classifiedAs(TranscriptionErrorKind kind, bool retryable) {
    return isA<TranscriptionException>()
        .having((e) => e.kind, 'kind', kind)
        .having((e) => e.isRetryable, 'isRetryable', retryable);
  }

  group('REINTENTABLE - errores de red y timeout -> kind network', () {
    test('SocketException', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientThrowing(const SocketException('Connection failed')),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.network, true)),
      );
    });

    test('http.ClientException', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientThrowing(http.ClientException('Connection reset')),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.network, true)),
      );
    });

    test('TimeoutException', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientThrowing(TimeoutException('Request timeout')),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.network, true)),
      );
    });

    test('HttpException', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientThrowing(const HttpException('Connection closed')),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.network, true)),
      );
    });

    test('HandshakeException (TLS roto a mitad de conexion)', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientThrowing(const HandshakeException('Handshake error')),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.network, true)),
      );
    });

    test('TlsException', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientThrowing(const TlsException('TLS error')),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.network, true)),
      );
    });
  });

  group('REINTENTABLE - servidor caido/saturado -> kind server (5xx, 429)', () {
    test('500 Internal Server Error', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientResponding(500),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.server, true)),
      );
    });

    test('503 Service Unavailable', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientResponding(503),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.server, true)),
      );
    });

    test('429 rate limit se trata como server reintentable', () async {
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientResponding(429),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.server, true)),
      );
    });
  });

  group('NO reintentable - credenciales invalidas -> kind auth (401/403)', () {
    test('401 API key invalida', () async {
      final service = CloudSttService(
        apiKey: 'gsk_invalida',
        client: clientResponding(401),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.auth, false)),
      );
    });

    test('403 prohibido tambien es auth', () async {
      final service = CloudSttService(
        apiKey: 'gsk_sin_permiso',
        client: clientResponding(403),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.auth, false)),
      );
    });

    test('API key vacia falla antes de la red como auth no reintentable',
        () async {
      const service = CloudSttService(apiKey: '');
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.auth, false)),
      );
    });
  });

  group('NO reintentable - media/request invalido -> kind badRequest', () {
    test('archivo inexistente', () async {
      const service = CloudSttService(apiKey: 'gsk_valid');
      await expectLater(
        service.transcribe('${tempDir.path}/no_existe.wav'),
        throwsA(classifiedAs(TranscriptionErrorKind.badRequest, false)),
      );
    });

    test('400 con detalle de Groq propaga el motivo y no es reintentable',
        () async {
      const groqBody =
          '{"error":{"message":"could not be processed - is it a valid media file?"}}';
      final service = CloudSttService(
        apiKey: 'gsk_valid',
        client: clientResponding(400, body: groqBody),
      );
      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>()
              .having((e) => e.kind, 'kind', TranscriptionErrorKind.badRequest)
              .having((e) => e.isRetryable, 'isRetryable', isFalse)
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('Error 400 de Groq'),
                  contains('valid media file'),
                ),
              ),
        ),
      );
    });
  });

  group('Contrato del getter TranscriptionException.isRetryable', () {
    test('kind network es reintentable', () {
      const exception = TranscriptionException(
        'Sin conexión a internet.',
        kind: TranscriptionErrorKind.network,
      );
      expect(exception.isRetryable, isTrue);
    });

    test('kind server es reintentable', () {
      const exception = TranscriptionException(
        'Error del servidor Groq (500). Intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
      );
      expect(exception.isRetryable, isTrue);
    });

    test('kind auth NO es reintentable', () {
      const exception = TranscriptionException(
        'API key inválida. Verifica tu clave en Settings.',
        kind: TranscriptionErrorKind.auth,
      );
      expect(exception.isRetryable, isFalse);
    });

    test('kind badRequest NO es reintentable', () {
      const exception = TranscriptionException(
        'Archivo de audio no encontrado.',
        kind: TranscriptionErrorKind.badRequest,
      );
      expect(exception.isRetryable, isFalse);
    });

    test('kind unknown (default) NO es reintentable', () {
      const exception = TranscriptionException('algo inesperado');
      expect(exception.kind, TranscriptionErrorKind.unknown);
      expect(exception.isRetryable, isFalse);
    });
  });

  group('NO hay reintento automatico: un envio HTTP por intento', () {
    test('fallo de red deja exactamente 1 request enviada', () async {
      var sendCount = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        sendCount++;
        throw const SocketException('Connection failed');
      });
      final service = CloudSttService(apiKey: 'gsk_valid', client: client);

      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(isA<TranscriptionException>()),
      );

      expect(sendCount, 1,
          reason: 'el reintento es decision de la UI, nunca del servicio');
    });

    test('fallo 401 deja exactamente 1 request enviada', () async {
      var sendCount = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        sendCount++;
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":{"message":"Invalid API Key"}}')),
          401,
        );
      });
      final service = CloudSttService(apiKey: 'gsk_invalida', client: client);

      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(classifiedAs(TranscriptionErrorKind.auth, false)),
      );

      expect(sendCount, 1);
    });

    test('fallo 500 deja exactamente 1 request enviada', () async {
      var sendCount = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        sendCount++;
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":{"message":"boom"}}')),
          500,
        );
      });
      final service = CloudSttService(apiKey: 'gsk_valid', client: client);

      await expectLater(
        service.transcribe(tempAudioFile.path),
        throwsA(isA<TranscriptionException>()),
      );

      expect(sendCount, 1);
    });
  });
}
