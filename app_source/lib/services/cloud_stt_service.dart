import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/transcription.dart';

/// Contrato de reintento (para la UI sin tocar screens/):
/// - Este servicio NUNCA reintenta por su cuenta: cada `transcribe()` envía
///   exactamente UNA petición HTTP, gane o pierda.
/// - Todo fallo se propaga como [TranscriptionException] con [TranscriptionErrorKind]
///   ya clasificado. El llamador decide con `e.isRetryable` (true solo para
///   `network`/`server`) si ofrece "Reintentar sin regrabar" o pide regrabar.
/// - `network`/`server` = reintentable; `auth`/`badRequest`/`unknown` = no.
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
  // --- Constantes del motor (sin literales mágicos) ---
  static const String _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String _model = 'whisper-large-v3';
  static const String _language = 'es';
  static const String _multipartFieldFile = 'file';
  static const String _multipartFieldModel = 'model';
  static const String _multipartFieldLanguage = 'language';
  static const String _headerAuthorization = 'Authorization';

  // Timeout adaptativo: 1 s por cada bloque completo subido + base.
  static const int _timeoutBaseSeconds = 60;
  static const int _timeoutBytesPerSecond = 50000; // ~50 KB/s efectivos
  static const int _timeoutMinSeconds = 60;
  static const int _timeoutMaxSeconds = 600;

  // Status HTTP clasificados.
  static const int _httpOk = 200;
  static const int _httpUnauthorized = 401;
  static const int _httpForbidden = 403;
  static const int _httpRateLimit = 429;
  static const int _httpServerErrorFloor = 500;

  /// Valores canonicos compartidos con el teclado nativo (espejo D7).
  static const String endpoint = _endpoint;
  static const String model = _model;
  static const String language = _language;

  final String apiKey;
  final http.Client? client;

  const CloudSttService({
    required this.apiKey,
    this.client,
  });

  /// Timeout adaptativo: base de procesamiento + 1 s por cada
  /// [_timeoutBytesPerSecond] bytes del audio (subida a ~50 KB/s efectivos
  /// en red móvil, conservador). WAV 16kHz mono 16-bit ≈ 32 KB/s de audio;
  /// clamp [_timeoutMinSeconds]..[_timeoutMaxSeconds].
  Duration timeoutForBytes(int bytes) {
    final seconds =
        _timeoutBaseSeconds + (bytes ~/ _timeoutBytesPerSecond);
    return Duration(seconds: seconds.clamp(_timeoutMinSeconds, _timeoutMaxSeconds));
  }

  Future<Transcription> transcribe(String audioPath) async {
    if (apiKey.isEmpty) {
      throw const TranscriptionException(
        'API key de Groq no configurada. Ve a Settings para agregarla.',
        kind: TranscriptionErrorKind.auth,
      );
    }

    final file = File(audioPath);
    // Async obligado: este chequeo corre en el hilo UI antes de subir a
    // Groq; el sync atascaba frames en eMMC lentas.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw const TranscriptionException(
        'Archivo de audio no encontrado.',
        kind: TranscriptionErrorKind.badRequest,
      );
    }

    final fileLength = await file.length();
    final timeout = timeoutForBytes(fileLength);

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.headers[_headerAuthorization] = 'Bearer $apiKey';
    request.fields[_multipartFieldModel] = _model;
    request.fields[_multipartFieldLanguage] = _language;
    try {
      request.files.add(
        await http.MultipartFile.fromPath(_multipartFieldFile, audioPath),
      );
    } on FileSystemException catch (e) {
      throw TranscriptionException(
        'No se pudo leer el audio para subirlo: ${e.message}',
        kind: TranscriptionErrorKind.badRequest,
      );
    } on OSError catch (e) {
      throw TranscriptionException(
        'No se pudo leer el audio para subirlo: ${e.message}',
        kind: TranscriptionErrorKind.badRequest,
      );
    } catch (_) {
      throw const TranscriptionException(
        'No se pudo leer el audio para subirlo.',
        kind: TranscriptionErrorKind.badRequest,
      );
    }

    final response = await _guardNetworkCall(() {
      final effectiveClient = client;
      final future = effectiveClient != null
          ? effectiveClient.send(request)
          : request.send();
      return future.timeout(timeout);
    });

    final body = await _guardNetworkCall(() {
      return response.stream.bytesToString().timeout(timeout);
    });

    if (response.statusCode == _httpOk) {
      return _parseSuccessBody(body);
    }

    if (response.statusCode == _httpUnauthorized ||
        response.statusCode == _httpForbidden) {
      throw const TranscriptionException(
        'API key inválida. Verifica tu clave en Settings.',
        kind: TranscriptionErrorKind.auth,
      );
    }
    if (response.statusCode == _httpRateLimit) {
      throw const TranscriptionException(
        'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
      );
    }
    if (response.statusCode >= _httpServerErrorFloor) {
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

  /// Parseo defensivo del 200 sin `as` duros: valida `text` String no vacío.
  /// - Body no-JSON o no-Map → `server` (payload del servidor malformado,
  ///   reintentable).
  /// - `text` ausente/no-String → `server` (reintentable).
  /// - `text` vacío/solo-espacios → `badRequest` (nada que transcribir en
  ///   ese audio; reintentar el mismo archivo no ayuda).
  Transcription _parseSuccessBody(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const TranscriptionException(
        'Respuesta inválida del servidor. Intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
      );
    }
    if (decoded is! Map<dynamic, dynamic>) {
      throw const TranscriptionException(
        'Respuesta inválida del servidor. Intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
      );
    }
    final rawText = decoded['text'];
    if (rawText is! String) {
      throw const TranscriptionException(
        'Respuesta inválida del servidor. Intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
      );
    }
    if (rawText.trim().isEmpty) {
      throw const TranscriptionException(
        'El servidor no devolvió texto para ese audio.',
        kind: TranscriptionErrorKind.badRequest,
      );
    }
    return Transcription(
      text: rawText,
      timestamp: DateTime.now(),
    );
  }

  Future<T> _guardNetworkCall<T>(Future<T> Function() call) async {
    try {
      return await call();
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
      // No tragar la clasificación ya decidida: el llamador la usa vía kind/isRetryable.
      if (e is TranscriptionException) rethrow;
      // Error inesperado fuera de red (p.ej. bug de programación): no
      // clasificar como red para no ofrecer un reintento inútil.
      throw const TranscriptionException(
        'Error inesperado al transcribir.',
        kind: TranscriptionErrorKind.unknown,
      );
    }
  }

  /// Propaga el motivo exacto que devuelve Groq en el body (ej. 400:
  /// formato de archivo inválido) para diagnóstico directo en la app.
  String _serverErrorDetail(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<dynamic, dynamic>) {
        final error = decoded['error'];
        final message =
            error is Map<dynamic, dynamic> ? error['message'] : null;
        if (message is String && message.isNotEmpty) {
          return 'Error $statusCode de Groq: $message';
        }
      }
    } catch (_) {}
    return 'Error del servidor Groq ($statusCode). Intenta de nuevo.';
  }
}
