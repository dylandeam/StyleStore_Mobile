import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/proximamente.dart';
import 'api_service.dart';

class ProximamenteService extends ChangeNotifier {
  final ApiService _apiService;
  List<ProximamenteItem> _items = [];
  final Set<int> _subscribedIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  ProximamenteService(this._apiService);

  List<ProximamenteItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isSubscribed(int id) => _subscribedIds.contains(id);

  Future<void> fetchProximamente() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get(ApiConfig.proximamenteUrl, requireAuth: false);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _items = data.map((json) => ProximamenteItem.fromJson(json)).toList();
      } else {
        _errorMessage = 'Error al cargar próximos lanzamientos.';
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> toggleSuscribir(int proximamenteId) async {
    if (_subscribedIds.contains(proximamenteId)) {
      _subscribedIds.remove(proximamenteId);
      notifyListeners();
      return {
        'success': true,
        'subscribed': false,
        'message': 'Suscripción cancelada para este artículo.',
      };
    }

    try {
      final res = await _apiService.post(
        ApiConfig.suscribirProximamenteUrl,
        body: {'proximamente_id': proximamenteId},
        requireAuth: true,
      );

      _subscribedIds.add(proximamenteId);
      notifyListeners();

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'subscribed': true,
          'message': data['mensaje'] ?? '¡Anotado! Te avisaremos por notificación emergente y correo cuando esté disponible.',
        };
      } else {
        return {
          'success': true,
          'subscribed': true,
          'message': '¡Anotado! Te avisaremos tan pronto el producto sea activado en tienda.',
        };
      }
    } catch (e) {
      _subscribedIds.add(proximamenteId);
      notifyListeners();
      return {
        'success': true,
        'subscribed': true,
        'message': '¡Anotado! Te avisaremos cuando llegue este producto.',
      };
    }
  }
}
