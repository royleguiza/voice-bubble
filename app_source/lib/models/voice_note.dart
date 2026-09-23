/// Nota de voz independiente del historial de transcripciones.
///
/// Contrato persistido en SharedPreferences clave `voice_notes_v1` como
/// string JSON array de objetos con claves `id` (String), `titulo` (String),
/// `cuerpo` (String), `createdAt` (String ISO-8601), `updatedAt` (String
/// ISO-8601) y `audioPath` opcional (String, ruta del WAV conservado).
/// El widget nativo lee la misma clave con prefijo `flutter.`.
/// No toca `transcriptions` (20 FIFO) ni snippets.
///
/// `audioPath`: WAV original conservado junto a la transcripción (pedido del
/// dueño 2026-09-23: el audio permanece aunque ya se transcribió). Null =
/// nota sin audio (notas viejas o creadas a mano). El archivo vive en
/// `getApplicationSupportDirectory()/notes_audio/` y se borra con la nota.
class VoiceNote {
  final String id;
  final String titulo;
  final String cuerpo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? audioPath;

  const VoiceNote({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.createdAt,
    required this.updatedAt,
    this.audioPath,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final titulo = json['titulo'];
    final cuerpo = json['cuerpo'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    final audioPath = json['audioPath'];
    return VoiceNote(
      id: id is String ? id : '',
      titulo: titulo is String ? titulo : '',
      cuerpo: cuerpo is String ? cuerpo : '',
      createdAt: _parse(createdAt),
      updatedAt: _parse(updatedAt),
      audioPath: audioPath is String && audioPath.isNotEmpty ? audioPath : null,
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
      if (audioPath != null && audioPath!.isNotEmpty) 'audioPath': audioPath,
    };
  }

  VoiceNote copyWith({
    String? id,
    String? titulo,
    String? cuerpo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? audioPath,
    bool clearAudioPath = false,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      cuerpo: cuerpo ?? this.cuerpo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
    );
  }

  /// True si la nota conserva el WAV original junto al texto.
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          titulo == other.titulo &&
          cuerpo == other.cuerpo &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          audioPath == other.audioPath;

  @override
  int get hashCode =>
      Object.hash(id, titulo, cuerpo, createdAt, updatedAt, audioPath);

  @override
  String toString() => 'VoiceNote(id: $id, titulo: $titulo)';
}
