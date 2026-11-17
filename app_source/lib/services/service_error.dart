/// Motivo de un error de servicio (Ruta IA, etapa 4).
///
/// Los servicios no tienen `BuildContext`: lanzan su excepción con un
/// [ServiceError] (más `code`/`detail`/`provider` cuando hace falta) y la
/// pantalla lo traduce con `serviceErrorText` (`l10n/service_error_text.dart`)
/// al idioma de la app. El `message` en español de cada excepción queda
/// solo para registros y pruebas.
enum ServiceError {
  // Transcripción (TranscriptionException).
  sttKeyMissing,
  audioNotFound,
  audioTooShort,
  audioTooLarge,
  audioDamaged, // detail = diagnóstico del WAV
  audioUnreadable,
  sttKeyInvalid,
  sttRateLimit,
  groqError, // code + detail = motivo que devuelve Groq
  groqServer, // code
  invalidResponse,
  emptyTranscript,
  noInternet,
  timeout,
  unexpectedTranscribe,
  micPermission,
  micBusy,
  uploadInFlight,
  historySaveFailed,

  // IA de notas (GeminiException).
  aiTimeout,
  aiNetwork,
  aiInvalidResponse,
  aiEmptyResponse,
  aiKeyInvalid, // provider + code + detail
  aiModelUnavailable, // detail
  aiLimit, // provider + detail
  aiServer, // code + detail
  aiHttp, // code + detail
  aiTooLong,
}
