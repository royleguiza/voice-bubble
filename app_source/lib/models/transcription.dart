class Transcription {
  final String text;
  final DateTime timestamp;
  final bool isLocal;

  const Transcription({
    required this.text,
    required this.timestamp,
    required this.isLocal,
  });

  factory Transcription.fromJson(Map<String, dynamic> json) {
    return Transcription(
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLocal: json['isLocal'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isLocal': isLocal,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transcription &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          timestamp == other.timestamp &&
          isLocal == other.isLocal;

  @override
  int get hashCode => Object.hash(text, timestamp, isLocal);
}
