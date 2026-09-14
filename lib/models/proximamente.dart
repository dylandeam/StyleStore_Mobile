class ProximamenteItem {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? foto;
  final String? fechaEstimada;
  final String? categoriaNombre;
  final String? temporadaNombre;
  final String? coleccionNombre;

  ProximamenteItem({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.foto,
    this.fechaEstimada,
    this.categoriaNombre,
    this.temporadaNombre,
    this.coleccionNombre,
  });

  factory ProximamenteItem.fromJson(Map<String, dynamic> json) {
    return ProximamenteItem(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      foto: json['foto'] as String?,
      fechaEstimada: json['fecha_estimada'] as String?,
      categoriaNombre: json['categoria_nombre'] as String?,
      temporadaNombre: json['temporada_nombre'] as String?,
      coleccionNombre: json['coleccion_nombre'] as String?,
    );
  }
}
