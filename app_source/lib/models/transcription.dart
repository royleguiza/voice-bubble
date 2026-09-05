/// Transcripción de voz a texto con timestamp de creación.
///
/// Formato canónico (contrato Flutter↔Kotlin K3):
/// - [toJson] produce `{'text': String, 'timestamp': String}` donde
///   `timestamp` es ISO-8601 según [DateTime.toIso8601String()]:
///   con sufijo `Z` cuando viene del teclado nativo (`Instant.now()` UTC),
///   sin zona cuando viene de la app (`DateTime.now()` local).
/// - [fromJson] acepta ese canónico y además tolera `timestamp` como
///   `int` (epoch), `String` (ISO-8601), `null` o ausente, sin lanzar:
///   `null`/ausente/ilegible cae a [DateTime.now()], `int` se interpreta
///   como milisegundos (o segundos si es < 1e10) desde epoch, `String`
///   se parsea con `tryParse` y cae a `now` si es ilegible. Todo timestamp
///   válido se normaliza a hora local con `toLocal()` para que el
///   historial muestre siempre la hora del usuario.
class Transcription {
  final String text;
  final DateTime timestamp;

  const Transcription({
    required this.text,
    required this.timestamp,
  });

  factory Transcription.fromJson(Map<String, dynamic> json) {
    final rawText = json['text'];
    final text = rawText is String ? rawText : '';
    return Transcription(
      text: text,
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  /// Parsea `timestamp` sin lanzar nunca. Ver contrato en la clase.
  static DateTime _parseTimestamp(Object? raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw.toLocal();
    if (raw is num) {
      final millis = raw < 10000000000 ? (raw * 1000).toInt() : raw.toInt();
      try {
        return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }
    if (raw is String) {
      if (raw.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(raw).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
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
