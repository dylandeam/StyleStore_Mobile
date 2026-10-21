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

  Future<Map<String, dynamic>> createPayPalOrder(
    String code, {
    required String returnUrl,
    required String cancelUrl,
  }) async {
    final response = await _api.post(
      '${ApiConfig.baseUrl}/planes/paypal/crear-orden',
      body: {
        'plan_codigo': code,
        'return_url': returnUrl,
        'cancel_url': cancelUrl,
      },
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'No se pudo iniciar el pago.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> capturePayPalOrder(String orderId) async {
    final response = await _api.post(
      '${ApiConfig.baseUrl}/planes/paypal/capturar-orden',
      body: {'paypal_order_id': orderId},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'PayPal no pudo confirmar el cobro.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
