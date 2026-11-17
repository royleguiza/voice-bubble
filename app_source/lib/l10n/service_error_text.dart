import '../services/cloud_stt_service.dart';
import '../services/gemini_note_service.dart';
import 'app_localizations.dart';

/// Texto de un error en el idioma de la app (Ruta IA, etapa 4).
///
/// Las excepciones de servicio traen un [ServiceError]; si no lo traen (o no
/// es una excepción conocida) se muestra `toString()` como antes.
String serviceErrorText(AppLocalizations l, Object error) {
  if (error is TranscriptionException) {
    final reason = error.reason;
    if (reason != null) return _text(l, reason, error.code, error.detail, '');
    return error.message;
  }
  if (error is GeminiException) {
    final reason = error.reason;
    if (reason != null) {
      return _text(l, reason, error.code, error.detail, error.provider);
    }
    return error.message;
  }
  return error.toString();
}

String _text(
  AppLocalizations l,
  ServiceError reason,
  int code,
  String detail,
  String provider,
) {
  final c = '$code';
  return switch (reason) {
    ServiceError.sttKeyMissing => l.errSttKeyMissing,
    ServiceError.audioNotFound => l.errAudioNotFound,
    ServiceError.audioTooShort => l.errAudioTooShort,
    ServiceError.audioTooLarge => l.errAudioTooLarge,
    ServiceError.audioDamaged => l.errAudioDamaged(detail),
    ServiceError.audioUnreadable => l.errAudioUnreadable,
    ServiceError.sttKeyInvalid => l.errSttKeyInvalid,
    ServiceError.sttRateLimit => l.errSttRateLimit,
    ServiceError.groqError => l.errGroqError(c, detail),
    ServiceError.groqServer => l.errGroqServer(c),
    ServiceError.invalidResponse => l.errInvalidResponse,
    ServiceError.emptyTranscript => l.errEmptyTranscript,
    ServiceError.noInternet => l.errNoInternet,
    ServiceError.timeout => l.errTimeout,
    ServiceError.unexpectedTranscribe => l.errUnexpectedTranscribe,
    ServiceError.micPermission => l.errMicPermission,
    ServiceError.micBusy => l.errMicBusy,
    ServiceError.uploadInFlight => l.errUploadInFlight,
    ServiceError.historySaveFailed => l.errHistorySaveFailed,
    ServiceError.aiTimeout => l.errAiTimeout,
    ServiceError.aiNetwork => l.errAiNetwork,
    ServiceError.aiInvalidResponse => l.errAiInvalidResponse,
    ServiceError.aiEmptyResponse => l.errAiEmptyResponse,
    ServiceError.aiKeyInvalid => l.errAiKeyInvalid(provider, c, detail).trim(),
    ServiceError.aiModelUnavailable => l.errAiModelUnavailable(detail),
    ServiceError.aiLimit => l.errAiLimit(provider, detail),
    ServiceError.aiServer => l.errAiServer(c, detail),
    ServiceError.aiHttp => l.errAiHttp(c, detail),
    ServiceError.aiTooLong => l.errAiTooLong,
  };
}
