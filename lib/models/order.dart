class OrderItem {
  final int id;
  final String codigo;
  final double total;
  final String estado;
  final String tipoVenta;
  final DateTime createdAt;
  final int? envioId;
  final String? envioEstado;

  OrderItem({
    required this.id,
    required this.codigo,
    required this.total,
    required this.estado,
    required this.tipoVenta,
    required this.createdAt,
    this.envioId,
    this.envioEstado,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int? ?? 0,
      codigo: json['codigo'] as String? ?? 'ORD-${json['id']}',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      estado: json['estado'] as String? ?? 'pendiente',
      tipoVenta: json['tipo_venta'] as String? ?? 'online',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      envioId: json['envio_id'] as int?,
      envioEstado: json['envio_estado'] as String?,
    );
  }
}
