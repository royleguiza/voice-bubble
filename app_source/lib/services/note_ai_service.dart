import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'gemini_key_store.dart';
import 'gemini_note_service.dart';
import 'storage_service.dart';

/// Acciones de IA sobre una nota (título y resumen), sea cual sea el
/// proveedor. Errores: [GeminiException] (nombre histórico, lo usan los dos).
abstract interface class NoteAiService {
  Future<String> sugerirTitulo(String texto);
  Future<String> resumir(String texto);

  /// Pedido mínimo para el botón «Probar conexión».
  Future<bool> testConnection();
}

/// Notas con Groq (`openai/gpt-oss-20b`): rápido, gratis con límites y con
/// la misma clave que la transcripción. Mismos prompts que Gemini.
///
/// Contrato (como [GeminiNoteService]): una sola petición por llamada, sin
/// reintentos; la clave va en `Authorization`, nunca en la URL ni en logs.
/// Espejo de `GroqNoteClient.kt` (widget): mismo modelo, prompts y topes.
class GroqNoteService implements NoteAiService {
  static const String model = 'openai/gpt-oss-20b';
  static const String endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _modelsEndpoint = 'https://api.groq.com/openai/v1/models';
  static const Duration timeout = Duration(seconds: 30);

  /// gpt-oss razona antes de responder y ese razonamiento cuenta en el tope:
  /// se deja margen para que la respuesta no salga vacía.
  static const int titleMaxTokens = 1024;
  static const int summaryMaxTokens = 4096;

  final String _apiKey;
  final http.Client _client;

  GroqNoteService({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  @override
  Future<String> sugerirTitulo(String texto) => _run(
        GeminiNoteService.promptTitulo.replaceAll('{texto}', texto),
        maxTokens: titleMaxTokens,
      );

  @override
  Future<String> resumir(String texto) => _run(
        GeminiNoteService.promptResumen.replaceAll('{texto}', texto),
        maxTokens: summaryMaxTokens,
      );

  /// Cuerpo del pedido (visible para tests).
  static String buildBody(String prompt, {required int maxTokens}) =>
      jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': GeminiNoteService.systemInstruction},
          {'role': 'user', 'content': prompt},
        ],
        'max_completion_tokens': maxTokens,
        // Razonamiento corto: es lo que hace rápida la respuesta.
        'reasoning_effort': 'low',
      });

  Future<String> _run(String prompt, {required int maxTokens}) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: buildBody(prompt, maxTokens: maxTokens),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiException('Tiempo de espera agotado',
          kind: GeminiErrorKind.network);
    } on Exception catch (e) {
      throw GeminiException('Error de red: $e', kind: GeminiErrorKind.network);
    }
    if (response.statusCode == 200) {
      String? text;
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        final message = (choices != null && choices.isNotEmpty)
            ? choices.first['message'] as Map?
            : null;
        text = message?['content'] as String?;
      } catch (_) {
        throw const GeminiException('Respuesta inválida',
            kind: GeminiErrorKind.unknown);
      }
      if (text == null || text.trim().isEmpty) {
        throw const GeminiException('Respuesta vacía del modelo',
            kind: GeminiErrorKind.unknown);
      }
      return text.trim();
    }
    final detail = _detail(response.body);
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      throw GeminiException('Clave de Groq inválida ($code) $detail',
          kind: GeminiErrorKind.auth);
    }
    if (code == 429) {
      throw GeminiException('Límite de Groq alcanzado: $detail',
          kind: GeminiErrorKind.server);
    }
    if (code >= 500) {
      throw GeminiException('Error del servidor ($code): $detail',
          kind: GeminiErrorKind.server);
    }
    throw GeminiException('Error $code: $detail',
        kind: GeminiErrorKind.badRequest);
  }

  static String _detail(String body) {
    final trimmed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}…';
  }

  @override
  Future<bool> testConnection() async {
    try {
      final res = await _client.get(Uri.parse(_modelsEndpoint),
          headers: {'Authorization': 'Bearer $_apiKey'}).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Elige con qué proveedor se hacen las acciones de IA de las notas.
///
/// Preferencia `kb_ai_notes_provider` ([StorageService.loadAiNotesProvider]:
/// `groq` por defecto, o `google`), compartida con el widget nativo. Si el
/// elegido no tiene clave, se usa el otro; sin ninguna clave no hay acciones.
class NoteAiResolver {
  static const String groq = StorageService.aiNotesProviderGroq;
  static const String google = StorageService.aiNotesProviderGoogle;

  final StorageService _storage;
  final GeminiKeyStore _geminiKeys;
  final FlutterSecureStorage _secure;

  NoteAiResolver({
    StorageService? storage,
    GeminiKeyStore? geminiKeys,
    FlutterSecureStorage? secure,
  })  : _storage = storage ?? StorageService(),
        _geminiKeys = geminiKeys ?? GeminiKeyStore(),
        _secure = secure ?? StorageService.espSecureStorage;

  Future<String?> _groqKey() async {
    try {
      final key = await _secure.read(key: StorageService.secureSttApiKey);
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}
    return null;
  }

  /// Proveedor que se va a usar de verdad (null = ninguno tiene clave).
  Future<String?> effectiveProvider() async {
    final wanted = await _storage.loadAiNotesProvider();
    final hasGroq = await _groqKey() != null;
    final hasGoogle = await _geminiKeys.hasKey();
    if (wanted == groq && hasGroq) return groq;
    if (wanted == google && hasGoogle) return google;
    if (hasGroq) return groq;
    if (hasGoogle) return google;
    return null;
  }

  /// Servicio listo para usar, o null si no hay ninguna clave.
  Future<NoteAiService?> create({http.Client? client}) async {
    switch (await effectiveProvider()) {
      case groq:
        final key = await _groqKey();
        return key == null ? null : GroqNoteService(apiKey: key, client: client);
      case google:
        final key = await _geminiKeys.getKey();
        return key == null
            ? null
            : GeminiNoteService(apiKey: key, client: client);
      default:
        return null;
    }
  }
}
