import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/gemini_key_store.dart';
import 'package:voice_bubble_stt/services/gemini_note_service.dart';
import 'package:voice_bubble_stt/services/note_ai_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

http.Response _groqOk(String content) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': content}
          }
        ]
      })),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroqNoteService (Ruta IA etapa 2a)', () {
    test('pide gpt-oss-20b con razonamiento corto y los mismos prompts',
        () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        expect(request.url.toString(), GroqNoteService.endpoint);
        expect(request.headers['Authorization'], 'Bearer gsk_test');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _groqOk('Compras del mes y corte');
      });
      final service = GroqNoteService(apiKey: 'gsk_test', client: client);
      final title = await service.sugerirTitulo('hoy compré pan y leche');
      expect(title, 'Compras del mes y corte');
      expect(sent['model'], 'openai/gpt-oss-20b');
      expect(sent['reasoning_effort'], 'low');
      expect(sent['max_completion_tokens'], GroqNoteService.titleMaxTokens);
      final messages = sent['messages'] as List;
      expect(messages.first['role'], 'system');
      expect(messages.first['content'], GeminiNoteService.systemInstruction);
      expect(messages.last['role'], 'user');
      expect(messages.last['content'], contains('hoy compré pan y leche'));
      expect(messages.last['content'], contains('Máximo 6 palabras'));
    });

    test('resumir usa el prompt de resumen y un tope mayor', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _groqOk('- punto uno\n- punto dos');
      });
      final res = await GroqNoteService(apiKey: 'k', client: client)
          .resumir('una nota larga');
      expect(res, '- punto uno\n- punto dos');
      expect(sent['max_completion_tokens'], GroqNoteService.summaryMaxTokens);
      expect((sent['messages'] as List).last['content'], contains('<= 30%'));
    });

    test('errores clasificados como en Gemini', () async {
      Future<void> expectKind(int code, GeminiErrorKind kind) async {
        final client = MockClient((_) async => http.Response('{}', code));
        await expectLater(
          GroqNoteService(apiKey: 'k', client: client).resumir('x'),
          throwsA(isA<GeminiException>().having((e) => e.kind, 'kind', kind)),
        );
      }

      await expectKind(401, GeminiErrorKind.auth);
      await expectKind(429, GeminiErrorKind.server);
      await expectKind(503, GeminiErrorKind.server);
      await expectKind(400, GeminiErrorKind.badRequest);
    });

    test('respuesta vacía es un error claro', () async {
      final client = MockClient((_) async => _groqOk('   '));
      await expectLater(
        GroqNoteService(apiKey: 'k', client: client).sugerirTitulo('x'),
        throwsA(isA<GeminiException>()),
      );
    });
  });

  group('NoteAiResolver', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    Future<void> setGroqKey() => StorageService.espSecureStorage
        .write(key: StorageService.secureSttApiKey, value: 'gsk_x');

    test('sin ninguna clave no hay proveedor', () async {
      final r = NoteAiResolver();
      expect(await r.effectiveProvider(), isNull);
      expect(await r.create(), isNull);
    });

    test('Groq por defecto con la clave de la transcripción', () async {
      await setGroqKey();
      final r = NoteAiResolver();
      expect(await StorageService().loadAiNotesProvider(), 'groq');
      expect(await r.effectiveProvider(), 'groq');
      expect(await r.create(), isA<GroqNoteService>());
    });

    test('Google elegido y con clave: Google', () async {
      await setGroqKey();
      await GeminiKeyStore().saveKey('AQ.google123456');
      await StorageService().saveAiNotesProvider('google');
      final r = NoteAiResolver();
      expect(await r.effectiveProvider(), 'google');
      expect(await r.create(), isA<GeminiNoteService>());
    });

    test('al elegido le falta la clave: usa el otro', () async {
      await setGroqKey();
      await StorageService().saveAiNotesProvider('google');
      expect(await NoteAiResolver().effectiveProvider(), 'groq');

      FlutterSecureStorage.setMockInitialValues({});
      await GeminiKeyStore().saveKey('AQ.google123456');
      await StorageService().saveAiNotesProvider('groq');
      expect(await NoteAiResolver().effectiveProvider(), 'google');
    });

    test('valor desconocido cae a Groq', () async {
      expect(StorageService.normalizeAiNotesProvider('otro'), 'groq');
      expect(StorageService.normalizeAiNotesProvider(null), 'groq');
      expect(StorageService.normalizeAiNotesProvider('google'), 'google');
    });
  });
}
