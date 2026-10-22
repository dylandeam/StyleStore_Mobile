import 'dart:convert';

import '../config/api_config.dart';
import 'api_service.dart';

class ExperienceService {
  final ApiService api;
  ExperienceService(this.api);

  Future<List<Map<String, dynamic>>> ratings() async {
    final response = await api.get(ApiConfig.experienciaCalificacionesUrl);
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las calificaciones.');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> claims() async {
    final response = await api.get(ApiConfig.experienciaReclamosUrl);
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los reclamos.');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> rate(
      int orderId, int score, String comment) async {
    final response =
        await api.post(ApiConfig.experienciaCalificacionesUrl, body: {
      'orden_venta_id': orderId,
      'puntuacion': score,
      'comentario': comment.trim().isEmpty ? null : comment.trim(),
    });
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['detail'] ?? 'No se pudo guardar la calificación.');
    }
    return data;
  }

  Future<Map<String, dynamic>> createClaim({
    required int branchId,
    required DateTime incidentDate,
    required String reason,
    required String description,
    int? orderId,
    int? ratingId,
  }) async {
    final response = await api.post(ApiConfig.experienciaReclamosUrl, body: {
      'sucursal_id': branchId,
      'fecha_incidente': incidentDate.toIso8601String().substring(0, 10),
      'motivo': reason,
      'descripcion': description.trim(),
      if (orderId != null) 'orden_venta_id': orderId,
      if (ratingId != null) 'calificacion_id': ratingId,
    });
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['detail'] ?? 'No se pudo registrar el reclamo.');
    }
    return data;
  }
}
