/// Snippet de texto reutilizable insertable desde el teclado (K4).
///
/// Las claves de [toJson]/[fromJson] forman parte del contrato compartido
/// con el teclado nativo Kotlin (persistido en SharedPreferences con la
/// clave "voice_snippets_v1"): no renombrarlas sin actualizar ambos lados.
class Snippet {
  final String id;
  final String nombre;
  final String contenido;
  final int orden;

  const Snippet({
    required this.id,
    required this.nombre,
    required this.contenido,
    required this.orden,
  });

  factory Snippet.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final contenido = json['contenido'];
    final orden = json['orden'];
    return Snippet(
      id: id is String ? id : '',
      nombre: nombre is String ? nombre : '',
      contenido: contenido is String ? contenido : '',
      orden: orden is num ? orden.toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'contenido': contenido,
      'orden': orden,
    };
  }

  Snippet copyWith({
    String? id,
    String? nombre,
    String? contenido,
    int? orden,
  }) {
    return Snippet(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contenido: contenido ?? this.contenido,
      orden: orden ?? this.orden,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Snippet &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          contenido == other.contenido &&
          orden == other.orden;

  @override
  int get hashCode => Object.hash(id, nombre, contenido, orden);

  @override
  String toString() => 'Snippet(id: $id, nombre: $nombre, orden: $orden)';
}
