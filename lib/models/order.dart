class OrderDetailItem {
  final int id;
  final String productoNombre;
  final String? colorNombre;
  final String? tallaNombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  OrderDetailItem({
    required this.id,
    required this.productoNombre,
    this.colorNombre,
    this.tallaNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory OrderDetailItem.fromJson(Map<String, dynamic> json) {
    return OrderDetailItem(
      id: json['id'] as int? ?? 0,
      productoNombre: json['producto_nombre'] as String? ?? 'Prenda',
      colorNombre: json['color_nombre'] as String?,
      tallaNombre: json['talla_nombre'] as String?,
      cantidad: json['cantidad'] as int? ?? 1,
      precioUnitario: double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class OrderItem {
  final int id;
  final String codigo;
  final double total;
  final String estado;
  final String tipoVenta;
  final DateTime createdAt;
  final int? sucursalId;
  final List<OrderDetailItem> detalles;
  final int? envioId;
  final String? envioEstado;
  final String? yangoTrackingCode;
  final String? yangoTrackingUrl;
  final String? deliveryConductor;

  OrderItem({
    required this.id,
    required this.codigo,
    required this.total,
    required this.estado,
    required this.tipoVenta,
    required this.createdAt,
    this.sucursalId,
    this.detalles = const [],
    this.envioId,
    this.envioEstado,
    this.yangoTrackingCode,
    this.yangoTrackingUrl,
    this.deliveryConductor,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final envio = json['envio'] as Map<String, dynamic>?;
    final rawDetalles = json['detalles'] as List<dynamic>? ?? [];

    return OrderItem(
      id: json['id'] as int? ?? 0,
      codigo: json['codigo'] as String? ?? 'ORD-${json['id']}',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      estado: json['estado'] as String? ?? 'pendiente',
      tipoVenta: json['tipo_venta'] as String? ?? 'online',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      sucursalId: json['sucursal_id'] as int?,
      detalles: rawDetalles.map((d) => OrderDetailItem.fromJson(d as Map<String, dynamic>)).toList(),
      envioId: json['envio_id'] as int? ?? (envio != null ? envio['id'] as int? : null),
      envioEstado: json['envio_estado'] as String? ?? (envio != null ? envio['estado'] as String? : null),
      yangoTrackingCode: json['yango_tracking_code'] as String? ??
          (envio != null ? envio['yango_tracking_code'] as String? : null),
      yangoTrackingUrl: json['yango_tracking_url'] as String? ??
          (envio != null ? envio['yango_tracking_url'] as String? : null),
      deliveryConductor: json['delivery_conductor'] as String? ??
          (envio != null ? envio['delivery_conductor'] as String? : null),
    );
  }
}
