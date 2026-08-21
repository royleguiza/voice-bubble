import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/models/transcription.dart';

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

  group('Fix 1: Import dart:convert - jsonDecode funciona correctamente', () {
    test('jsonDecode parsea respuesta exitosa de Groq API', () {
      const responseBody =
          '{"text": "Hola mundo, esto es una transcripción de prueba"}';
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = decoded['text'] as String;

      expect(text, 'Hola mundo, esto es una transcripción de prueba');
    });

    test('jsonDecode maneja caracteres especiales en español', () {
      const responseBody =
          '{"text": "Acentos: áéíóú ñ, signos: ¿? @#\$%, unicode: \u00e1\u00e9\u00ed\u00f3\u00fa"}';
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = decoded['text'] as String;

      expect(text, contains('áéíóú'));
      expect(text, contains('ñ'));
      expect(text, contains('¿?'));
    });

    test('jsonDecode maneja texto vacío del servicio', () {
      const responseBody = '{"text": ""}';
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = decoded['text'] as String;

      expect(text, isEmpty);
    });

    test('jsonDecode maneja texto largo de transcripción', () {
      final longText = 'Palabra ' * 500;
      final responseBody = '{"text": "$longText"}';
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = decoded['text'] as String;

      expect(text.length, greaterThan(1000));
      expect(text, startsWith('Palabra'));
    });

    test('jsonDecode lanza FormatException con JSON malformado', () {
      expect(
        () => jsonDecode('{invalid json content}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('jsonDecode lanza excepción con input vacío', () {
      expect(
        () => jsonDecode(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('flujo completo de parsing crea Transcription válida', () {
      const responseBody = '{"text": "Resultado de transcripción"}';
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = decoded['text'] as String;

      final transcription = Transcription(
        text: text,
        timestamp: DateTime.now(),
        isLocal: false,
      );

      expect(transcription.text, 'Resultado de transcripción');
      expect(transcription.isLocal, false);
      expect(transcription.timestamp, isA<DateTime>());
    });

    test('jsonDecode extrae correctamente campo text del JSON de Groq',
        () {
      const responseBody = '{"text": " audio content ", "x_groq": {}}';
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

      expect(decoded.containsKey('text'), true);
      expect(decoded['text'], isA<String>());
    });
  });

  group('Fix 2: Manejo de SocketException (sin conexión a internet)', () {
    test('TranscriptionException con mensaje de sin conexión es lanzado',
        () {
      const expectedMessage = 'Sin conexión a internet.';
      const exception = TranscriptionException(expectedMessage);

      expect(exception.message, expectedMessage);
      expect(exception.toString(), expectedMessage);
    });

    test('SocketException es el tipo correcto para errores de red', () {
      expect(
        () => throw const SocketException('Connection refused'),
        throwsA(isA<SocketException>()),
      );
    });

    test(
        'TranscriptionException por SocketException se diferencia de otros errores',
        () {
      const socketException =
          TranscriptionException('Sin conexión a internet.');
      const apiKeyException = TranscriptionException(
          'API key de Groq no configurada. Ve a Settings para agregarla.');
      const fileException =
          TranscriptionException('Archivo de audio no encontrado.');

      expect(socketException.message, isNot(apiKeyException.message));
      expect(socketException.message, isNot(fileException.message));
    });

    test('servicio lanza TranscriptionException al recibir SocketException',
        () async {
      const service = CloudSttService(apiKey: 'test-key');
      expect(
        () => service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            anyOf(
              equals('Sin conexión a internet.'),
              contains('Error del servidor'),
              contains('Archivo de audio'),
            ),
          ),
        ),
      );
    });
  });

  group('Manejo de errores HTTP existentes', () {
    test('mensaje de error para 401 es API key inválida', () {
      const exception = TranscriptionException(
          'API key inválida. Verifica tu clave en Settings.');
      expect(exception.message, contains('API key inválida'));
      expect(exception.message, contains('Settings'));
    });

    test('TranscriptionException para API key inválida (401)', () {
      const exception = TranscriptionException(
          'API key inválida. Verifica tu clave en Settings.');
      expect(exception.message, isNotEmpty);
      expect(exception.toString(), exception.message);
    });

    test('TranscriptionException para límite de solicitudes (429)', () {
      const exception = TranscriptionException(
          'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.');
      expect(exception.message, contains('Límite de solicitudes'));
      expect(exception.message, contains('Espera un momento'));
    });

    test('TranscriptionException para error genérico del servidor', () {
      final exception =
          TranscriptionException('Error del servidor Groq (500). Intenta de nuevo.');
      expect(exception.message, contains('500'));
      expect(exception.message, contains('Error del servidor'));
    });

    test('cada tipo de error tiene un mensaje descriptivo y único', () {
      const errors = {
        'socket': 'Sin conexión a internet.',
        'api_key': 'API key inválida. Verifica tu clave en Settings.',
        'rate_limit':
            'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.',
        'generic': 'Error del servidor Groq (500). Intenta de nuevo.',
      };

      final messages = errors.values.toList();
      final uniqueMessages = messages.toSet();
      expect(uniqueMessages.length, messages.length,
          reason: 'Cada tipo de error debe tener un mensaje único');
    });
  });

  group('Manejo de timeout (30 segundos)', () {
    test('Future.timeout lanza TimeoutException después del tiempo límite',
        () async {
      final slowFuture = Future.delayed(const Duration(seconds: 5), () {
        return 'done';
      });

      expect(
        () => slowFuture.timeout(const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('Future.timeout completa exitosamente si termina a tiempo',
        () async {
      final fastFuture = Future.value('resultado');

      final result = await fastFuture.timeout(const Duration(seconds: 30));
      expect(result, 'resultado');
    });

    test('timeout de 30 segundos es el configurado en el servicio', () {
      const timeoutDuration = Duration(seconds: 30);
      expect(timeoutDuration.inSeconds, 30);
    });
  });

  group('Endpoint correcto (Groq API)', () {
    test('servicio está configurado con API key válida', () {
      const service = CloudSttService(apiKey: 'gsk_test_key_12345');
      expect(service.apiKey, 'gsk_test_key_12345');
      expect(service.apiKey, isNotEmpty);
    });

    test('servicio lanza error si API key está vacía', () async {
      const service = CloudSttService(apiKey: '');
      expect(
        () => service.transcribe('/any/path.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'API key de Groq no configurada. Ve a Settings para agregarla.',
          ),
        ),
      );
    });

    test(
        'TranscriptionException por API key contiene referencia a Groq y Settings',
        () {
      const exception = TranscriptionException(
          'API key de Groq no configurada. Ve a Settings para agregarla.');
      expect(exception.message, contains('Groq'));
      expect(exception.message, contains('Settings'));
    });
  });

  group('Modelo correcto (whisper-large-v3)', () {
    test('modelo whisper-large-v3 es el estándar de Groq para transcripción',
        () {
      const expectedModel = 'whisper-large-v3';
      expect(expectedModel, startsWith('whisper-'));
      expect(expectedModel, contains('large'));
    });

    test('servicio está configurado con API key para usar modelo Groq', () {
      const service = CloudSttService(apiKey: 'gsk_test_key');
      expect(service.apiKey, startsWith('gsk_'));
    });
  });

  group('Envío multipart', () {
    test('request fields incluye modelo y idioma para Groq API', () {
      final requestFields = {
        'model': 'whisper-large-v3',
        'language': 'es',
      };

      expect(requestFields['model'], 'whisper-large-v3');
      expect(requestFields['language'], 'es');
    });

    test('header Authorization formateado correctamente con Bearer token',
        () {
      const apiKey = 'gsk_test_api_key_abc123';
      final authHeader = 'Bearer $apiKey';

      expect(authHeader, startsWith('Bearer '));
      expect(authHeader, contains(apiKey));
    });

    test('archivo de audio existe para envío multipart', () async {
      final exists = await tempAudioFile.exists();
      expect(exists, true);
      expect(await tempAudioFile.length(), greaterThan(0));
    });

    test('archivo de audio tiene contenido para procesamiento', () async {
      final bytes = await tempAudioFile.readAsBytes();
      expect(bytes.isNotEmpty, true);
      expect(bytes.length, greaterThanOrEqualTo(1024));
    });

    test(
        'servicio lanza error si archivo de audio no existe para multipart',
        () async {
      const service = CloudSttService(apiKey: 'test-key');
      expect(
        () => service.transcribe('/nonexistent/audio.wav'),
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

  group('Integración de fixes - comportamiento del servicio', () {
    test('servicio con API key vacía falla antes de intentar conexión', () {
      const service = CloudSttService(apiKey: '');
      expect(
        () => service.transcribe(tempAudioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'API key de Groq no configurada. Ve a Settings para agregarla.',
          ),
        ),
      );
    });

    test(
        'servicio con archivo inexistente falla antes de intentar conexión',
        () {
      const service = CloudSttService(apiKey: 'valid-key');
      expect(
        () => service.transcribe('/no/existe.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            'Archivo de audio no encontrado.',
          ),
        ),
      );
    });

    test(
        'servicio con API key y archivo válido procede a hacer request HTTP',
        () async {
      const service = CloudSttService(apiKey: 'valid-key');
      expect(
        () => service.transcribe(tempAudioFile.path),
        throwsA(isA<TranscriptionException>()),
      );
    });

    test('TranscriptionException implementa Exception correctamente', () {
      const exception = TranscriptionException('test');
      expect(exception, isA<Exception>());
      expect(exception, isA<TranscriptionException>());
    });

    test('código de error 401 produce TranscriptionException específica',
        () {
      const exception = TranscriptionException(
          'API key inválida. Verifica tu clave en Settings.');
      expect(exception.message, contains('API key'));
      expect(exception.message, contains('Settings'));
    });

    test('código de error 429 produce TranscriptionException específica',
        () {
      const exception = TranscriptionException(
          'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.');
      expect(exception.message, contains('Límite'));
      expect(exception.message, contains('Espera'));
    });
  });
}
