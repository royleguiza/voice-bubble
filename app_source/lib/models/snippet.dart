/// Snippet de texto reutilizable insertable desde el teclado (K4).
///
/// Las claves de [toJson]/[fromJson] forman parte del contrato compartido
/// con el teclado nativo Kotlin (persistido en SharedPreferences con la
/// clave "voice_snippets_v1"): no renombrarlas sin actualizar ambos lados.
/// [color] es opcional (aditivo): id de la paleta fija de 6; null = default.
class Snippet {
  final String id;
  final String nombre;
  final String contenido;
  final int orden;
  final String? color;

  const Snippet({
    required this.id,
    required this.nombre,
    required this.contenido,
    required this.orden,
    this.color,
  });

  factory Snippet.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final contenido = json['contenido'];
    final orden = json['orden'];
    final color = json['color'];
    return Snippet(
      id: id is String ? id : '',
      nombre: nombre is String ? nombre : '',
      contenido: contenido is String ? contenido : '',
      orden: orden is num ? orden.toInt() : 0,
      color: color is String && kSnippetColorIds.contains(color) ? color : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'contenido': contenido,
      'orden': orden,
      if (color != null) 'color': color,
    };
  }

  Snippet copyWith({
    Object? id = _sentinel,
    Object? nombre = _sentinel,
    Object? contenido = _sentinel,
    Object? orden = _sentinel,
    Object? color = _sentinel,
  }) {
    return Snippet(
      id: id == _sentinel ? this.id : id as String,
      nombre: nombre == _sentinel ? this.nombre : nombre as String,
      contenido:
          contenido == _sentinel ? this.contenido : contenido as String,
      orden: orden == _sentinel ? this.orden : orden as int,
      color: color == _sentinel ? this.color : color as String?,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Snippet &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          contenido == other.contenido &&
          orden == other.orden &&
          color == other.color;

  @override
  int get hashCode => Object.hash(id, nombre, contenido, orden, color);

  @override
  String toString() => 'Snippet(id: $id, nombre: $nombre, orden: $orden)';
}

/// Paleta fija de 6 ids de color de snippets (design.md §12).
/// No existe color libre fuera de esta lista.
const List<String> kSnippetColorIds = [
  'azul',
  'verde',
  'rojo',
  'naranja',
  'violeta',
  'gris',
];
