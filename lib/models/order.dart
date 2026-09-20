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
  // Delivery StyleStore - Rastreo
  final String? trackingCode;
  final String? trackingUrl;
  final String? tokenSeguimiento;
  final String? deliveryConductor;
  // GPS del repartidor
  final double? repartidorLat;
  final double? repartidorLon;
  final String? repartidorNombre;
  final double? latitudDestino;
  final double? longitudDestino;
  final int? minutosEstimados;

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
    this.trackingCode,
    this.trackingUrl,
    this.tokenSeguimiento,
    this.deliveryConductor,
    this.repartidorLat,
    this.repartidorLon,
    this.repartidorNombre,
    this.latitudDestino,
    this.longitudDestino,
    this.minutosEstimados,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final envio = json['envio'] as Map<String, dynamic>?;
    final rawDetalles = json['detalles'] as List<dynamic>? ?? [];

    // Tracking: leer de los campos nuevos, con fallback a los viejos yango_*
    String? code = json['tracking_code'] as String?
        ?? json['yango_tracking_code'] as String?
        ?? (envio != null ? (envio['tracking_code'] ?? envio['yango_tracking_code']) as String? : null);
    String? url = json['tracking_url'] as String?
        ?? json['yango_tracking_url'] as String?
        ?? (envio != null ? (envio['tracking_url'] ?? envio['yango_tracking_url']) as String? : null);
    String? token = json['token_seguimiento'] as String?
        ?? (envio != null ? envio['token_seguimiento'] as String? : null);

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
      trackingCode: code,
      trackingUrl: url,
      tokenSeguimiento: token,
      deliveryConductor: json['delivery_conductor'] as String?
          ?? (envio != null ? envio['delivery_conductor'] as String? : null),
      repartidorLat: _parseDouble(envio?['repartidor_lat']),
      repartidorLon: _parseDouble(envio?['repartidor_lon']),
      repartidorNombre: envio?['repartidor_nombre'] as String?,
      latitudDestino: _parseDouble(envio?['latitud_destino']),
      longitudDestino: _parseDouble(envio?['longitud_destino']),
      minutosEstimados: envio?['minutos_estimados'] as int?,
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
