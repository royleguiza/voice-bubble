import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/transcription.dart';

/// Clasificación de errores de transcripción para decidir si conviene
/// ofrecer reintento sin regrabar.
enum TranscriptionErrorKind {
  /// Sin conexión / red intermitente / timeout.
  network,

  /// El servidor falló o está saturado (5xx, 429).
  server,

  /// API key inválida o ausente.
  auth,

  /// Archivo inválido o request malformada (4xx distinto de auth/429).
  badRequest,

  /// Cualquier otro caso.
  unknown,
}

class TranscriptionException implements Exception {
  final String message;
  final TranscriptionErrorKind kind;

  const TranscriptionException(this.message, {this.kind = TranscriptionErrorKind.unknown});

  /// Network y server valen la pena reintentar; auth/badRequest no.
  bool get isRetryable =>
      kind == TranscriptionErrorKind.network || kind == TranscriptionErrorKind.server;

  @override
  String toString() => message;
}

class CloudSttService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String _model = 'whisper-large-v3';

  /// Valores canonicos compartidos con el teclado nativo (espejo D7).
  static const String endpoint = _endpoint;
  static const String model = _model;
  static const String provider = 'groq';
  static const String language = 'es';

  final String apiKey;
  final http.Client? client;

  const CloudSttService({
    required this.apiKey,
    this.client,
  });

  /// Timeout adaptativo: subida (~125 KB/s en red móvil) + procesamiento.
  /// WAV 16kHz mono 16-bit ≈ 32 KB/s de audio; clamp [60s, 600s].
  Duration timeoutForBytes(int bytes) {
    final seconds = 60 + (bytes ~/ 50000);
    return Duration(seconds: seconds.clamp(60, 600));
  }

  Future<Transcription> transcribe(String audioPath) async {
    if (apiKey.isEmpty) {
      throw const TranscriptionException(
        'API key de Groq no configurada. Ve a Settings para agregarla.',
        kind: TranscriptionErrorKind.auth,
      );
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw const TranscriptionException(
        'Archivo de audio no encontrado.',
        kind: TranscriptionErrorKind.badRequest,
      );
    }

    final fileLength = await file.length();
    final timeout = timeoutForBytes(fileLength);

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = _model;
    request.fields['language'] = 'es';
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    http.StreamedResponse response;
    try {
      final effectiveClient = client;
      final future = effectiveClient != null
          ? effectiveClient.send(request)
          : request.send();
      response = await future.timeout(timeout);
    } on SocketException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on http.ClientException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on HttpException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on HandshakeException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on TlsException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on TimeoutException {
      throw const TranscriptionException(
        'Tiempo de espera agotado al conectar con el servidor.',
        kind: TranscriptionErrorKind.network,
      );
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    }

    final String body;
    try {
      body = await response.stream.bytesToString().timeout(timeout);
    } on SocketException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on http.ClientException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on HttpException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on HandshakeException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on TlsException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    } on TimeoutException {
      throw const TranscriptionException(
        'Tiempo de espera agotado al conectar con el servidor.',
        kind: TranscriptionErrorKind.network,
      );
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network);
    }

    if (response.statusCode == 200) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final text = decoded['text'] as String;
      return Transcription(
        text: text,
        timestamp: DateTime.now(),
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const TranscriptionException(
        'API key inválida. Verifica tu clave en Settings.',
        kind: TranscriptionErrorKind.auth,
      );
    }
    if (response.statusCode == 429) {
      throw const TranscriptionException(
        'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
      );
    }
    if (response.statusCode >= 500) {
      throw TranscriptionException(
        _serverErrorDetail(response.statusCode, body),
        kind: TranscriptionErrorKind.server,
      );
    }

    throw TranscriptionException(
      _serverErrorDetail(response.statusCode, body),
      kind: TranscriptionErrorKind.badRequest,
    );
  }

  /// Propaga el motivo exacto que devuelve Groq en el body (ej. 400:
  /// formato de archivo inválido) para diagnóstico directo en la app.
  String _serverErrorDetail(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        final message = error is Map ? error['message'] : null;
        if (message is String && message.isNotEmpty) {
          return 'Error $statusCode de Groq: $message';
        }
      }
    } catch (_) {}
    return 'Error del servidor Groq ($statusCode). Intenta de nuevo.';
  }
}
