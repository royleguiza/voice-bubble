import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_bubble_stt/services/gemini_note_service.dart';

void main() {
  group('GeminiNoteService', () {
    test('sugerirTitulo parsea respuesta 200', () async {
      final client = MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'test-key');
        expect(request.url.path, contains('generateContent'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Corte mensual y compras'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });
      final service = GeminiNoteService(apiKey: 'test-key', client: client);
      final res = await service.sugerirTitulo('nota de prueba');
      expect(res, 'Corte mensual y compras');
    });

    test('401 mapea a GeminiErrorKind.auth', () async {
      final client = MockClient((request) async => http.Response('{}', 401));
      final service = GeminiNoteService(apiKey: 'bad', client: client);
      await expectLater(
        service.reestructurar('x'),
        throwsA(isA<GeminiException>().having(
            (e) => e.kind, 'kind', GeminiErrorKind.auth)),
      );
    });

    test('429 mapea a server y es reintentable', () async {
      final client = MockClient((request) async => http.Response('{}', 429));
      final service = GeminiNoteService(apiKey: 'k', client: client);
      await expectLater(
        service.investigar('x'),
        throwsA(isA<GeminiException>()
            .having((e) => e.kind, 'kind', GeminiErrorKind.server)
            .having((e) => e.isRetryable, 'retryable', true)),
      );
    });

    test('respuesta sin candidates lanza unknown', () async {
      final client = MockClient(
          (request) async => http.Response(jsonEncode({}), 200));
      final service = GeminiNoteService(apiKey: 'k', client: client);
      await expectLater(
        service.sugerirTitulo('x'),
        throwsA(isA<GeminiException>()),
      );
    });

    test('testConnection true en 200 y false en error', () async {
      final okClient = MockClient((request) async => http.Response('{}', 200));
      expect(
          await GeminiNoteService(apiKey: 'k', client: okClient)
              .testConnection(),
          true);
      final badClient = MockClient((request) async => http.Response('{}', 403));
      expect(
          await GeminiNoteService(apiKey: 'k', client: badClient)
              .testConnection(),
          false);
    });
  });
}
