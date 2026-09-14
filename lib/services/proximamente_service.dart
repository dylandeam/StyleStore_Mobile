import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/proximamente.dart';
import 'api_service.dart';

class ProximamenteService extends ChangeNotifier {
  final ApiService _apiService;
  List<ProximamenteItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  ProximamenteService(this._apiService);

  List<ProximamenteItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
}
