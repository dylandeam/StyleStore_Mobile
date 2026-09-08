class Producto {
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String? foto;
  final double precio;
  final int categoriaId;
  final String? categoriaNombre;
  final int temporadaId;
  final String? temporadaNombre;
  final bool active;
  final List<String> colores;
  final int stockTotal;

  Producto({
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.foto,
    required this.precio,
    required this.categoriaId,
    this.categoriaNombre,
    required this.temporadaId,
    this.temporadaNombre,
    required this.active,
    required this.colores,
    required this.stockTotal,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    List<String> parsedColores = [];
    if (json['colores'] != null && json['colores'] is List) {
      parsedColores = (json['colores'] as List)
          .map((c) => c['nombre']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Producto(
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      foto: json['foto'],
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      categoriaId: json['categoria_id'] ?? 0,
      categoriaNombre: json['categoria_nombre'],
      temporadaId: json['temporada_id'] ?? 0,
      temporadaNombre: json['temporada_nombre'],
      active: json['active'] ?? true,
      colores: parsedColores,
      stockTotal: json['stock_total'] ?? 0,
    );
  }
}
