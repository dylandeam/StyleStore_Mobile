class OrderItem {
  final int id;
  final String codigo;
  final double total;
  final String estado;
  final String tipoVenta;
  final DateTime createdAt;
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
    this.envioId,
    this.envioEstado,
    this.yangoTrackingCode,
    this.yangoTrackingUrl,
    this.deliveryConductor,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final envio = json['envio'] as Map<String, dynamic>?;

    return OrderItem(
      id: json['id'] as int? ?? 0,
      codigo: json['codigo'] as String? ?? 'ORD-${json['id']}',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      estado: json['estado'] as String? ?? 'pendiente',
      tipoVenta: json['tipo_venta'] as String? ?? 'online',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
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
