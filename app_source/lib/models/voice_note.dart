/// Nota de voz independiente del historial de transcripciones.
///
/// Contrato persistido en SharedPreferences clave `voice_notes_v1` como
/// string JSON array de objetos con claves `id` (String), `titulo` (String),
/// `cuerpo` (String), `createdAt` (String ISO-8601), `updatedAt` (String
/// ISO-8601). El widget nativo lee la misma clave con prefijo `flutter.`.
/// No toca `transcriptions` (20 FIFO) ni snippets.
class VoiceNote {
  final String id;
  final String titulo;
  final String cuerpo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VoiceNote({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final titulo = json['titulo'];
    final cuerpo = json['cuerpo'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    return VoiceNote(
      id: id is String ? id : '',
      titulo: titulo is String ? titulo : '',
      cuerpo: cuerpo is String ? cuerpo : '',
      createdAt: _parse(createdAt),
      updatedAt: _parse(updatedAt),
    );
  }

  static DateTime _parse(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final p = DateTime.tryParse(raw);
      if (p != null) return p.toLocal();
    }
    if (raw is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw).toLocal();
      } catch (_) {}
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'cuerpo': cuerpo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  VoiceNote copyWith({
    String? id,
    String? titulo,
    String? cuerpo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      cuerpo: cuerpo ?? this.cuerpo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          titulo == other.titulo &&
          cuerpo == other.cuerpo &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, titulo, cuerpo, createdAt, updatedAt);

  @override
  String toString() => 'VoiceNote(id: $id, titulo: $titulo)';
}
