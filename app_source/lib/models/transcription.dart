/// Transcripción de voz a texto con timestamp de creación.
///
/// Formato canónico (contrato Flutter↔Kotlin K3 / C-21):
/// - [toJson] produce `{'text': String, 'timestamp': String}` donde
///   `timestamp` es ISO-8601 según [DateTime.toIso8601String()]:
///   con sufijo `Z` cuando viene del teclado nativo (`Instant.now()` UTC),
///   sin zona cuando viene de la app local.
/// - [fromJson] delega en [tryFromJson]: si el timestamp es ilegible o corrupto,
///   lanza [FormatException] y JAMÁS inventa [DateTime.now()] (C-21: lo corrupto
///   se descarta, nunca se premia para que no gane un merge).
/// - [tryFromJson] devuelve `null` ante timestamp presente pero ilegible.
class Transcription {
  final String text;
  final DateTime timestamp;

  const Transcription({
    required this.text,
    required this.timestamp,
  });

  /// Identificador único para widgets y claves de lista (C-33).
  String get id => '${timestamp.millisecondsSinceEpoch}_${text.hashCode}';

  factory Transcription.fromJson(Map<String, dynamic> json) {
    final parsed = tryFromJson(json);
    if (parsed != null) return parsed;
    throw const FormatException('Timestamp de transcripción inválido o corrupto');
  }

  /// SPK-18 / C-21: no inventa tiempo para basura. Devuelve null si hay
  /// `timestamp` presente-pero-ilegible o corrupto; el llamador descarta.
  static Transcription? tryFromJson(Map<String, dynamic> json) {
    final raw = json['timestamp'];
    if (raw is String && (raw.isEmpty || DateTime.tryParse(raw) == null)) {
      return null;
    }
    if (raw is num && (raw.isNaN || raw.isInfinite)) {
      return null;
    }
    final rawText = json['text'];
    final text = rawText is String ? rawText : '';
    final parsedTime = _parseTimestamp(raw);
    return Transcription(
      text: text,
      timestamp: parsedTime,
    );
  }

  /// Parsea `timestamp` de forma segura. Devuelve null ante entradas corruptas (C-21).
  static DateTime? tryParseTimestamp(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is num) {
      if (raw.isNaN || raw.isInfinite) return null;
      final millis = raw < 10000000000 ? (raw * 1000).toInt() : raw.toInt();
      try {
        return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      } catch (_) {
        return null;
      }
    }
    if (raw is String) {
      if (raw.isEmpty) return null;
      try {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toLocal();
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Parsea `timestamp` sin inventar `DateTime.now()`: ante null/ausente usa EPOCH (1970).
  static DateTime _parseTimestamp(Object? raw) {
    return tryParseTimestamp(raw) ?? DateTime.fromMillisecondsSinceEpoch(0).toLocal();
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transcription &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(text, timestamp);

  @override
  String toString() => 'Transcription(text: $text, timestamp: $timestamp)';
}
