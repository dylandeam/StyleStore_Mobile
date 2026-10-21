import 'dart:convert';

import '../config/api_config.dart';
import '../models/subscription_plan.dart';
import 'api_service.dart';

class PlansService {
  final ApiService _api;
  const PlansService(this._api);

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _api.get('${ApiConfig.baseUrl}/planes');
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los planes.');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) =>
            SubscriptionPlan.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Map<String, dynamic>?> getMyContract() async {
    final response =
        await _api.get('${ApiConfig.baseUrl}/planes/mi-contratacion');
    if (response.statusCode != 200 || response.body == 'null') return null;
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> contract(String code) async {
    final response = await _api.post(
      '${ApiConfig.baseUrl}/planes/contratar',
      body: {
        'plan_codigo': code,
        'pago_confirmado': true,
        'referencia_pago':
            'MOBILE-SIM-${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'No se pudo contratar el plan.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
