class ReservaItem {
  final int id;
  final String codigo;
  final DateTime fechaLimite;
  final String estado;
  final double totalEstimado;
  final String? sucursalNombre;

  ReservaItem({
    required this.id,
    required this.codigo,
    required this.fechaLimite,
    required this.estado,
    required this.totalEstimado,
    this.sucursalNombre,
  });

  factory ReservaItem.fromJson(Map<String, dynamic> json) {
    return ReservaItem(
      id: json['id'] as int? ?? 0,
      codigo: json['codigo'] as String? ?? 'RES-${json['id']}',
      fechaLimite: json['fecha_limite'] != null
          ? DateTime.parse(json['fecha_limite'] as String)
          : DateTime.now().add(const Duration(hours: 48)),
      estado: json['estado'] as String? ?? 'pendiente',
      totalEstimado: double.tryParse(json['total_estimado']?.toString() ?? '0') ?? 0.0,
      sucursalNombre: json['sucursal_nombre'] as String?,
    );
  }
}
