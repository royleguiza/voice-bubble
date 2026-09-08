/// Credencial guardada por el usuario para relleno desde el teclado.
///
/// Solo identificadores no sensibles: la contraseña NUNCA viaja en este
/// modelo. Vive aparte en el mapa de [StorageService.credPassKey] indexado
/// por [id] dentro de la bóveda cifrada, y la UI jamás la lee de vuelta
/// (sin ojo, sin edición: ante un error se borra y se crea de nuevo).
///
/// Las claves de [toJson]/[fromJson] forman parte del contrato compartido
/// con el teclado nativo Kotlin (índice persistido en SharedPreferences con
/// la clave "vb_credentials_v1"): no renombrarlas sin actualizar ambos lados.
class VbCredential {
  final String id;
  final String nombre;
  final String usuario;

  const VbCredential({
    required this.id,
    required this.nombre,
    required this.usuario,
  });

  factory VbCredential.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final usuario = json['usuario'];
    return VbCredential(
      id: id is String ? id : '',
      nombre: nombre is String ? nombre : '',
      usuario: usuario is String ? usuario : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'usuario': usuario,
    };
  }

  VbCredential copyWith({
    String? id,
    String? nombre,
    String? usuario,
  }) {
    return VbCredential(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      usuario: usuario ?? this.usuario,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VbCredential &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          usuario == other.usuario;

  @override
  int get hashCode => Object.hash(id, nombre, usuario);

  // Sin password en toString por diseño: este objeto nunca porta secretos.
  @override
  String toString() => 'VbCredential(id: $id, nombre: $nombre)';
}
