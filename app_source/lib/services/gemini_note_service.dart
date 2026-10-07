import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Servicio on-demand de acciones IA sobre notas (Gemini).
/// Contrato:
/// - Cada llamada ejecuta exactamente UNA petición HTTP (no reintenta).
/// - Fallos como [GeminiException] con [GeminiErrorKind] clasificado.
/// - La key viaja en header `x-goog-api-key`, nunca en la URL ni en logs.
enum GeminiErrorKind { network, server, auth, badRequest, unknown }

class GeminiException implements Exception {
  final String message;
  final GeminiErrorKind kind;
  const GeminiException(this.message, {this.kind = GeminiErrorKind.unknown});
  bool get isRetryable =>
      kind == GeminiErrorKind.network || kind == GeminiErrorKind.server;
  @override
  String toString() => message;
}

class GeminiNoteService {
  static const String model = 'gemini-3.5-flash';
  static const Duration timeout = Duration(seconds: 30);
  static const String _modelsEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const String systemInstruction =
      'Respondé siempre en el mismo idioma en que esté escrita la nota. Salvo '
      'que se indique lo contrario, devolvé texto plano sin markdown ni emojis. '
      'No inventes información que no esté en la nota.';

  final http.Client _client;
  final String _apiKey;

  GeminiNoteService({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  static const String promptTitulo = '''
Analizá la siguiente nota dictada por voz y proponé UN título en el mismo
idioma de la nota.
Reglas:
- Máximo 6 palabras y 60 caracteres.
- Sin comillas, sin punto final, sin emojis.
- Debe capturar el tema principal, no una palabra suelta: no respondas con
  una categoría genérica ni con el idioma objetivo del dictado.
- Respondé ÚNICAMENTE el título, sin prefijos ni explicaciones.
- Si la nota no tiene tema claro, devolvé "Nota sin título".

Nota:
"""{texto}"""''';

  static const String promptResumen = '''
Resumí la siguiente nota dictada por voz.
Reglas estrictas:
- El resumen debe ser mucho más corto que la nota original (objetivo <= 30%
  del texto, sin extenderse si no hace falta).
- Mencioná solo lo más importante: hechos, decisiones, fechas y nombres que
  aparezcan en la nota. NO inventes datos ni conclusiones.
- Usá viñetas cortas para los puntos clave; una línea inicial con el tema.
- Mantené el idioma de la nota original.
- Texto plano, sin encabezados inventados.

Nota:
"""{texto}"""''';


  Future<String> sugerirTitulo(String texto) => _run(
        _fill(promptTitulo, texto),
        maxOutputTokens: 256,
      );

  Future<String> resumir(String texto) => _run(
        _fill(promptResumen, texto),
        maxOutputTokens: 2048,
      );

  static String _fill(String template, String texto) =>
      template.replaceAll('{texto}', texto);

  Future<String> _run(String prompt,
      {required int maxOutputTokens}) async {
    final uri = Uri.parse('$_modelsEndpoint/$model:generateContent');
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'thinkingConfig': {'thinkingLevel': 'minimal'},
      },
    });

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiException('Tiempo de espera agotado',
          kind: GeminiErrorKind.network);
    } on Exception catch (e) {
      throw GeminiException('Error de red: $e', kind: GeminiErrorKind.network);
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(data);
        if (text == null || text.trim().isEmpty) {
          final reason = _finishReason(data);
          throw GeminiException(
              'Respuesta vacía del modelo (finishReason: $reason)',
              kind: GeminiErrorKind.unknown);
        }
        return text.trim();
      } on GeminiException {
        rethrow;
      } catch (_) {
        throw const GeminiException('Respuesta inválida',
            kind: GeminiErrorKind.unknown);
      }
    }
    final detail = _bodyDetail(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GeminiException('API key inválida (${response.statusCode}) $detail',
          kind: GeminiErrorKind.auth);
    }
    if (response.statusCode == 404) {
      throw GeminiException('Modelo no disponible: $detail',
          kind: GeminiErrorKind.badRequest);
    }
    if (response.statusCode == 429) {
      throw GeminiException('Cuota agotada: $detail',
          kind: GeminiErrorKind.server);
    }
    if (response.statusCode >= 500) {
      throw GeminiException('Error del servidor (${response.statusCode}): $detail',
          kind: GeminiErrorKind.server);
    }
    throw GeminiException('Error ${response.statusCode}: $detail',
        kind: GeminiErrorKind.badRequest);
  }

  static String _finishReason(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return 'sin candidatos';
      return '${candidates.first['finishReason'] ?? 'desconocido'}';
    } catch (_) {
      return 'desconocido';
    }
  }

  static String? _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates.first['content'] as Map?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      return parts.first['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String _bodyDetail(String body) {
    final trimmed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= 200) return trimmed;
    return '${trimmed.substring(0, 200)}…';
  }

  /// Prueba ligera de la key (un token) para el botón "Probar conexión".
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse(_modelsEndpoint);
      final res = await _client
          .get(uri, headers: {'x-goog-api-key': _apiKey}).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
