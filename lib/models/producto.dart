class Producto {
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String? foto;
  final String? fotoTrasera;
  final String? fotoVestidorFrontal;
  final String? fotoVestidorTrasera;
  final String tipoPrenda;
  final double precio;
  final int categoriaId;
  final String? categoriaNombre;
  final int temporadaId;
  final String? temporadaNombre;
  final int? coleccionId;
  final String? coleccionNombre;
  final bool active;
  final bool visibleEnCatalogo;
  final List<String> colores;
  final int stockTotal;

  Producto({
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.foto,
    this.fotoTrasera,
    this.fotoVestidorFrontal,
    this.fotoVestidorTrasera,
    this.tipoPrenda = 'superior',
    required this.precio,
    required this.categoriaId,
    this.categoriaNombre,
    required this.temporadaId,
    this.temporadaNombre,
    this.coleccionId,
    this.coleccionNombre,
    required this.active,
    this.visibleEnCatalogo = true,
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
      fotoTrasera: json['foto_trasera'],
      fotoVestidorFrontal: json['foto_vestidor_frontal'],
      fotoVestidorTrasera: json['foto_vestidor_trasera'],
      tipoPrenda: json['tipo_prenda'] ?? 'superior',
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      categoriaId: json['categoria_id'] ?? 0,
      categoriaNombre: json['categoria_nombre'],
      temporadaId: json['temporada_id'] ?? 0,
      temporadaNombre: json['temporada_nombre'],
      coleccionId: json['coleccion_id'],
      coleccionNombre: json['coleccion_nombre'],
      active: json['active'] ?? true,
      visibleEnCatalogo: json['visible_en_catalogo'] ?? true,
      colores: parsedColores,
      stockTotal: json['stock_total'] ?? 0,
    );
  }
}
