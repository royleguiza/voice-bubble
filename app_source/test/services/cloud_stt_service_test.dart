import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';

void main() {
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
  });

  group('CloudSttService.transcribe', () {
    test('empty API key throws TranscriptionException', () async {
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

    test('whitespace-only API key is not considered empty', () async {
      const service = CloudSttService(apiKey: '   ');
      expect(
        () => service.transcribe('/nonexistent/path.wav'),
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
      expect(
        () => service.transcribe('/definitely/does/not/exist.wav'),
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
      expect(
        () => service.transcribe('/tmp/missing_audio.mp3'),
        throwsA(
          isA<TranscriptionException>(),
        ),
      );
    });

    test('empty path throws TranscriptionException for missing file', () async {
      const service = CloudSttService(apiKey: 'key');
      expect(
        () => service.transcribe(''),
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

  group('CloudSttService constants', () {
    test('is a const constructible class', () {
      const service = CloudSttService(apiKey: 'test');
      expect(service.apiKey, 'test');
    });
  });
}
