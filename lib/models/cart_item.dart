class CartItem {
  final int id;
  final int productoColorId;
  final int tallaId;
  final int sucursalId;
  final String? sucursalNombre;
  final String? sucursalCiudad;
  final String productoNombre;
  final String? colorNombre;
  final String? tallaNombre;
  final String? foto;
  final double precioUnitario;
  int cantidad;
  final double subtotal;

  CartItem({
    required this.id,
    required this.productoColorId,
    required this.tallaId,
    required this.sucursalId,
    this.sucursalNombre,
    this.sucursalCiudad,
    required this.productoNombre,
    this.colorNombre,
    this.tallaNombre,
    this.foto,
    required this.precioUnitario,
    required this.cantidad,
    required this.subtotal,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as int? ?? 0,
      productoColorId: json['producto_color_id'] as int? ?? 0,
      tallaId: json['talla_id'] as int? ?? 0,
      sucursalId: json['sucursal_id'] as int? ?? 0,
      sucursalNombre: json['sucursal_nombre'] as String?,
      sucursalCiudad: json['sucursal_ciudad'] as String?,
      productoNombre: json['producto_nombre'] as String? ?? 'Prenda StyleStore',
      colorNombre: json['color_nombre'] as String?,
      tallaNombre: json['talla_nombre'] as String?,
      foto: json['foto'] as String?,
      precioUnitario: double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      cantidad: json['cantidad'] as int? ?? 1,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
    );
  }
}
