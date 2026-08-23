class Transcription {
  final String text;
  final DateTime timestamp;

  const Transcription({
    required this.text,
    required this.timestamp,
  });

  factory Transcription.fromJson(Map<String, dynamic> json) {
    return Transcription(
      text: (json['text'] as String?) ?? '',
      timestamp: json['timestamp'] != null
          // El teclado Kotlin serializa en UTC (Instant); toLocal() unifica
          // con los dictados de la app (DateTime.now() local) para que el
          // historial muestre siempre la hora real del usuario.
          ? DateTime.parse(json['timestamp'] as String).toLocal()
          : DateTime.now(),
    );
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
