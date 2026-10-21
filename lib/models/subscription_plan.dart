class SubscriptionPlan {
  final String code;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int? maxBranches;
  final bool generativeAi;
  final Map<String, bool> capabilities;
  final List<String> benefits;
  final Map<String, dynamic> style;

  const SubscriptionPlan({
    required this.code,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.maxBranches,
    required this.generativeAi,
    required this.capabilities,
    required this.benefits,
    required this.style,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        code: json['codigo']?.toString() ?? '',
        name: json['nombre']?.toString() ?? '',
        description: json['descripcion']?.toString(),
        price: double.tryParse(json['precio_mensual']?.toString() ?? '') ?? 0,
        currency: json['moneda']?.toString() ?? 'BOB',
        maxBranches: int.tryParse(json['max_sucursales']?.toString() ?? ''),
        generativeAi: json['ia_generativa'] == true,
        capabilities: Map<String, dynamic>.from(
          json['capacidades'] as Map? ?? const {},
        ).map((key, value) => MapEntry(key, value == true)),
        benefits: (json['beneficios'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList(),
        style: Map<String, dynamic>.from(json['estilo'] as Map? ?? const {}),
      );
}
