import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/transcription.dart';
import '../ui/app_locale.dart';
import 'service_error.dart';

export 'service_error.dart';

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

  /// Motivo para mostrarlo traducido (null = mostrar [message]).
  final ServiceError? reason;

  /// Código HTTP, si lo hay (0 = ninguno).
  final int code;

  /// Detalle técnico que se muestra tal cual (motivo del servidor, etc.).
  final String detail;

  const TranscriptionException(
    this.message, {
    this.kind = TranscriptionErrorKind.unknown,
    this.reason,
    this.code = 0,
    this.detail = '',
  });

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
  static const String _model = 'whisper-large-v3-turbo';
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
  static const int _timeoutReadSeconds = 60; // Lectura fija separada de subida
  static const Duration timeoutRead = Duration(seconds: _timeoutReadSeconds);

  /// Tope máximo de audio para la API Whisper (25 MB).
  static const int maxFileSizeBytes = 25 * 1024 * 1024;

  // Status HTTP clasificados.
  static const int _httpOk = 200;
  static const int _httpUnauthorized = 401;
  static const int _httpForbidden = 403;
  static const int _httpRateLimit = 429;
  static const int _httpServerErrorFloor = 500;

  /// Valores canonicos compartidos con el teclado nativo (espejo D7).
  static const String endpoint = _endpoint;

  /// Modelo por defecto (rápido). El elegido en Ajustes vive en
  /// `kb_stt_model` y lo leen la app y el teclado nativo.
  static const String model = _model;

  /// Idioma en que se habla por defecto. El elegido en Ajustes («Idioma en
  /// que hablo») vive en `kb_stt_language` y lo leen la app y el teclado.
  static const String language = _language;

  /// «Automático»: no se manda `language` y Whisper detecta el idioma.
  static const String autoLanguage = 'auto';

  /// Idiomas que se pueden elegir en Ajustes (mismo orden que el menú).
  /// Idiomas que se pueden fijar (Whisper entiende ~100; acá van los más
  /// hablados, plan de lanzamiento §10). Cada uno con su propio nombre.
  static const Map<String, String> languageNames = {
    'es': 'Español',
    'en': 'English',
    'pt': 'Português',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'tr': 'Türkçe',
    'ru': 'Русский',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
  };

  static const List<String> languages = [
    autoLanguage, 'es', 'en', 'pt', 'fr', 'de', 'it', 'nl', 'pl', 'tr',
    'ru', 'ar', 'hi', 'id', 'zh', 'ja', 'ko',
  ];

  /// Lo guardado en `kb_stt_language` → un valor válido (desconocido o vacío
  /// cae a español). Espejo de `SpeechToTextClient.resolveLanguage`.
  static String normalizeLanguage(String? raw) {
    final value = raw?.trim();
    if (value != null && languages.contains(value)) return value;
    // Sin elección (o inválida): el idioma de la app, si Whisper lo tiene en
    // la lista (pedido del 25/11: app en inglés y dictado forzado a español).
    final app = appLanguageCode();
    return (app != autoLanguage && languages.contains(app)) ? app : _language;
  }

  /// Idioma en que se ve la app: el elegido en Ajustes o el del teléfono.
  static String appLanguageCode() {
    final chosen = appLocale.value?.languageCode;
    if (chosen != null) return chosen;
    return ui.PlatformDispatcher.instance.locale.languageCode;
  }


  /// Modelo preciso de Groq: un poco más lento, menos errores y mejor
  /// puntuación (error por palabra 10,3 % contra 12 % del turbo).
  static const String preciseModel = 'whisper-large-v3';

  /// Modelos que se pueden elegir en Ajustes (mismo orden que el menú).
  static const List<String> models = [_model, preciseModel];

  /// Lo guardado en `kb_stt_model` → un modelo válido (desconocido o vacío
  /// cae al rápido). Espejo de `SpeechToTextClient.resolveModel`.
  static String normalizeModel(String? raw) {
    final value = raw?.trim();
    return (value != null && models.contains(value)) ? value : _model;
  }

  /// Umbral mínimo de audio útil (8000 bytes, ~0.25 s a 16kHz 16-bit mono).
  /// Por debajo de 8000B se descarta como click o ruido vacío.
  static const int minAudioBytes = 8000;

  /// Huella de cabecera para diagnóstico en dispositivo (C-44): primeros
  /// 4 bytes en hex + ASCII + tamaño. Solo metadatos, jamás contenido.
  /// Ej: "52494646/RIFF/8236", "00000000/..../8236", "7b227472/{\"tr/312".
  static String describeHead(List<int> bytes, int fileLength) {
    final StringBuffer hex = StringBuffer();
    final StringBuffer ascii = StringBuffer();
    for (var i = 0; i < 4 && i < bytes.length; i++) {
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      final int c = bytes[i];
      ascii.write(c >= 32 && c < 127 ? String.fromCharCode(c) : '.');
    }
    return '$hex/$ascii/$fileLength';
  }

  /// Arma una cabecera WAV PCM 16-bit mono 16kHz (nuestro formato propio).
  static List<int> buildWavHeader(int dataSize) {
    void u16(List<int> out, int v) {
      out.add(v & 0xFF);
      out.add((v >> 8) & 0xFF);
    }

    void u32(List<int> out, int v) {
      u16(out, v & 0xFFFF);
      u16(out, (v >> 16) & 0xFFFF);
    }

    void tag(List<int> out, String s) {
      for (var i = 0; i < 4; i++) {
        out.add(s.codeUnitAt(i));
      }
    }

    final List<int> head = <int>[];
    tag(head, 'RIFF');
    u32(head, dataSize + 36);
    tag(head, 'WAVE');
    tag(head, 'fmt ');
    u32(head, 16);
    u16(head, 1);
    u16(head, 1);
    u32(head, 16000);
    u32(head, 32000);
    u16(head, 2);
    u16(head, 16);
    tag(head, 'data');
    u32(head, dataSize);
    assert(head.length == 44);
    return head;
  }

  /// Intenta rescatar un PCM nuestro sin tapa (C-45): hueco de 44 ceros +
  /// audio real detrás (stop anormal). Devuelve los bytes reparados o null
  /// (vacío, extranjero o ilegible: se mantiene el error claro).
  static Future<List<int>?> tryRepairHolePcm(
    File file,
    List<int> head,
    int fileLength,
  ) async {
    if (fileLength <= 44 || head.length < 44) return null;
    for (var i = 0; i < 44; i++) {
      if (head[i] != 0) return null;
    }
    var content = false;
    for (var i = 44; i < head.length; i++) {
      if (head[i] != 0) {
        content = true;
        break;
      }
    }
    if (!content) {
      final int tailLen =
          fileLength > 8192 ? 4096 : fileLength;
      final RandomAccessFile raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(fileLength - tailLen);
        final List<int> tail = await raf.read(tailLen);
        for (final int b in tail) {
          if (b != 0) {
            content = true;
            break;
          }
        }
      } finally {
        await raf.close();
      }
    }
    if (!content) return null;
    final int dataSize = fileLength - 44;
    if (dataSize <= 0) return null;
    final RandomAccessFile raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(44);
      final List<int> body = await raf.read(dataSize);
      if (body.length != dataSize) return null;
      return buildWavHeader(dataSize) + body;
    } finally {
      await raf.close();
    }
  }

  /// Motivo del rechazo del validador WAV (C-43): se muestra entre
  /// corchetes para diagnosticar en dispositivo sin exponer contenido.
  /// Solo tamaños, jamás audio.
  static String checkWavHeader(List<int> bytes, int fileLength) {
    if (bytes.length < 12 || fileLength < 44) return 'corto';
    int u32(int o) {
      if (o + 4 > bytes.length) return -1;
      return bytes[o] |
          (bytes[o + 1] << 8) |
          (bytes[o + 2] << 16) |
          (bytes[o + 3] << 24);
    }

    bool magic(int o, String s) {
      if (o + 4 > bytes.length) return false;
      return bytes[o] == s.codeUnitAt(0) &&
          bytes[o + 1] == s.codeUnitAt(1) &&
          bytes[o + 2] == s.codeUnitAt(2) &&
          bytes[o + 3] == s.codeUnitAt(3);
    }

    if (!magic(0, 'RIFF') || !magic(8, 'WAVE')) return 'no-riff';
    final int riffSize = u32(4);
    if (riffSize < 0 || riffSize + 8 > fileLength) return 'riff-tamano';
    var pos = 12;
    var fmtFound = false;
    while (pos + 8 <= bytes.length) {
      final int size = u32(pos + 4);
      if (size < 0) return 'chunk-roto';
      if (magic(pos, 'fmt ')) fmtFound = true;
      if (magic(pos, 'data')) {
        if (!fmtFound) return 'sin-fmt';
        if (size <= 0) return 'vacio';
        if (pos + 8 + size > fileLength) return 'trunco';
        return 'ok';
      }
      pos += 8 + size + (size % 2);
    }
    return 'sin-data';
  }

  /// Valida contenedor WAV (C-42/C-43): recorre los sub-chunks (tolera
  /// extras como JUNK/LIST/fact que escriben grabadores reales) y exige
  /// RIFF/WAVE, un chunk fmt, un chunk data con tamaño consistente. No
  /// juzga sample-rate ni canales (Groq remuestrea): solo detecta
  /// truncados y basura que Groq rechazaría con 400 "valid media file".
  static bool isValidWavHeader(List<int> bytes, int fileLength) =>
      checkWavHeader(bytes, fileLength) == 'ok';

  final String apiKey;
  final http.Client? client;

  /// Modelo con el que se transcribe (uno de [models]).
  final String sttModel;

  /// Idioma en que se habla (uno de [languages]; `auto` = detectar).
  final String sttLanguage;

  const CloudSttService({
    required this.apiKey,
    this.client,
    this.sttModel = _model,
    this.sttLanguage = _language,
  });

  /// Crea una copia del servicio conservando el [client] (y la clave si no se pasa).
  CloudSttService copyWith({
    String? apiKey,
    http.Client? client,
    String? sttModel,
    String? sttLanguage,
  }) {
    return CloudSttService(
      apiKey: apiKey ?? this.apiKey,
      client: client ?? this.client,
      sttModel: sttModel ?? this.sttModel,
      sttLanguage: sttLanguage ?? this.sttLanguage,
    );
  }

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
        reason: ServiceError.sttKeyMissing,
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
        reason: ServiceError.audioNotFound,
      );
    }

    final fileLength = await file.length();
    if (fileLength < minAudioBytes) {
      throw const TranscriptionException(
        'El archivo de audio es demasiado corto para transcribir (mínimo 8000 bytes).',
        kind: TranscriptionErrorKind.badRequest,
        reason: ServiceError.audioTooShort,
      );
    }
    if (fileLength > maxFileSizeBytes) {
      throw const TranscriptionException(
        'El archivo de audio supera el límite de 25 MB.',
        kind: TranscriptionErrorKind.badRequest,
        reason: ServiceError.audioTooLarge,
      );
    }
    // C-42: validar integridad ANTES de subir (solo cabecera, barato).
    // Un truncado/garbage pasaba los tamaños y Groq lo rechazaba con 400.
    final RandomAccessFile raf = await file.open(mode: FileMode.read);
    List<int> head;
    try {
      head = await raf.read(4096);
    } finally {
      await raf.close();
    }
    List<int>? repaired;
    if (!isValidWavHeader(head, fileLength)) {
      repaired = await tryRepairHolePcm(file, head, fileLength);
      // C-45: el reparado se persiste en disco (best-effort) para que el
      // audio conservado (notes_audio) y los reintentos/pendientes vean un
      // WAV sano y reproducible. Sin esto la nota quedaba con texto pero
      // audio irreproducible aunque la subida saliera.
      if (repaired != null) {
        try {
          await file.writeAsBytes(repaired, flush: true);
        } catch (_) {}
      }
    }
    if (repaired == null && !isValidWavHeader(head, fileLength)) {
      final String motivo = checkWavHeader(head, fileLength);
      final String huella = describeHead(head, fileLength);
      throw TranscriptionException(
        'El audio está dañado [$motivo $huella] y no se puede transcribir. Grabalo de nuevo.',
        kind: TranscriptionErrorKind.badRequest,
        reason: ServiceError.audioDamaged,
        detail: '$motivo $huella',
      );
    }
    final timeout = timeoutForBytes(fileLength);

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.headers[_headerAuthorization] = 'Bearer $apiKey';
    request.fields[_multipartFieldModel] = normalizeModel(sttModel);
    final spokenLanguage = normalizeLanguage(sttLanguage);
    if (spokenLanguage != autoLanguage) {
      request.fields[_multipartFieldLanguage] = spokenLanguage;
    }
    final http.MultipartFile audioPart;
    if (repaired != null) {
      audioPart = http.MultipartFile.fromBytes(
        _multipartFieldFile,
        repaired,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav'),
      );
    } else {
      try {
        audioPart = await http.MultipartFile.fromPath(
          _multipartFieldFile,
          audioPath,
          filename: 'audio.wav',
          contentType: MediaType('audio', 'wav'),
        );
      } on FileSystemException catch (e) {
        throw TranscriptionException(
          'No se pudo leer el audio para subirlo: ${e.message}',
          kind: TranscriptionErrorKind.badRequest,
          reason: ServiceError.audioUnreadable,
        );
      } on OSError catch (e) {
        throw TranscriptionException(
          'No se pudo leer el audio para subirlo: ${e.message}',
          kind: TranscriptionErrorKind.badRequest,
          reason: ServiceError.audioUnreadable,
        );
      } catch (_) {
        throw const TranscriptionException(
          'No se pudo leer el audio para subirlo.',
          kind: TranscriptionErrorKind.badRequest,
          reason: ServiceError.audioUnreadable,
        );
      }
    }
    request.files.add(audioPart);

    final response = await _guardNetworkCall(() {
      final effectiveClient = client;
      final future = effectiveClient != null
          ? effectiveClient.send(request)
          : request.send();
      return future.timeout(timeout);
    });

    final body = await _guardNetworkCall(() {
      return response.stream.bytesToString().timeout(timeoutRead);
    });

    if (response.statusCode == _httpOk) {
      return _parseSuccessBody(body);
    }

    if (response.statusCode == _httpUnauthorized ||
        response.statusCode == _httpForbidden) {
      throw const TranscriptionException(
        'API key inválida. Verifica tu clave en Settings.',
        kind: TranscriptionErrorKind.auth,
        reason: ServiceError.sttKeyInvalid,
      );
    }
    if (response.statusCode == _httpRateLimit) {
      throw const TranscriptionException(
        'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
        reason: ServiceError.sttRateLimit,
      );
    }
    if (response.statusCode >= _httpServerErrorFloor) {
      throw _serverError(response.statusCode, body,
          TranscriptionErrorKind.server);
    }

    throw _serverError(response.statusCode, body,
        TranscriptionErrorKind.badRequest);
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
        reason: ServiceError.invalidResponse,
      );
    }
    if (decoded is! Map<dynamic, dynamic>) {
      throw const TranscriptionException(
        'Respuesta inválida del servidor. Intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
        reason: ServiceError.invalidResponse,
      );
    }
    final rawText = decoded['text'];
    if (rawText is! String) {
      throw const TranscriptionException(
        'Respuesta inválida del servidor. Intenta de nuevo.',
        kind: TranscriptionErrorKind.server,
        reason: ServiceError.invalidResponse,
      );
    }
    if (rawText.trim().isEmpty) {
      throw const TranscriptionException(
        'El servidor no devolvió texto para ese audio.',
        kind: TranscriptionErrorKind.badRequest,
        reason: ServiceError.emptyTranscript,
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
          kind: TranscriptionErrorKind.network,
          reason: ServiceError.noInternet);
    } on http.ClientException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network,
          reason: ServiceError.noInternet);
    } on HttpException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network,
          reason: ServiceError.noInternet);
    } on HandshakeException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network,
          reason: ServiceError.noInternet);
    } on TlsException {
      throw const TranscriptionException('Sin conexión a internet.',
          kind: TranscriptionErrorKind.network,
          reason: ServiceError.noInternet);
    } on TimeoutException {
      throw const TranscriptionException(
        'Tiempo de espera agotado al conectar con el servidor.',
        kind: TranscriptionErrorKind.network,
        reason: ServiceError.timeout,
      );
    } catch (e) {
      // No tragar la clasificación ya decidida: el llamador la usa vía kind/isRetryable.
      if (e is TranscriptionException) rethrow;
      // Error inesperado fuera de red (p.ej. bug de programación): no
      // clasificar como red para no ofrecer un reintento inútil.
      throw const TranscriptionException(
        'Error inesperado al transcribir.',
        kind: TranscriptionErrorKind.unknown,
        reason: ServiceError.unexpectedTranscribe,
      );
    }
  }

  /// Error HTTP de Groq con el motivo que devuelve (traducible por [ServiceError]).
  TranscriptionException _serverError(
      int statusCode, String body, TranscriptionErrorKind kind) {
    final reason = _groqReason(body);
    return TranscriptionException(
      _serverErrorDetail(statusCode, body),
      kind: kind,
      reason: reason.isEmpty ? ServiceError.groqServer : ServiceError.groqError,
      code: statusCode,
      detail: reason,
    );
  }

  /// Motivo de Groq saneado y recortado ('' si el body no lo trae).
  String _groqReason(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<dynamic, dynamic>) {
        final error = decoded['error'];
        final message =
            error is Map<dynamic, dynamic> ? error['message'] : null;
        if (message is String && message.isNotEmpty) {
          final sanitized = message.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
          return sanitized.length > 200
              ? '${sanitized.substring(0, 200)}…'
              : sanitized;
        }
      }
    } catch (_) {}
    return '';
  }

  /// Propaga el motivo exacto que devuelve Groq en el body (ej. 400:
  /// formato de archivo inválido) para diagnóstico directo en la app.
  String _serverErrorDetail(int statusCode, String body) {
    final reason = _groqReason(body);
    return reason.isNotEmpty
        ? 'Error $statusCode de Groq: $reason'
        : 'Error del servidor Groq ($statusCode). Intenta de nuevo.';
  }
}
