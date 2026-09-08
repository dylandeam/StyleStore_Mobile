import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/producto.dart';
import 'api_service.dart';

class CatalogService extends ChangeNotifier {
  final ApiService _apiService;
  List<Producto> _productos = [];
  bool _isLoading = false;
  String? _errorMessage;

  CatalogService(this._apiService);

  List<Producto> get productos => _productos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(
        '${ApiConfig.baseUrl}/productos',
        requireAuth: true,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _productos = data.map((json) => Producto.fromJson(json)).toList();
      } else {
        _errorMessage = 'Error al cargar catálogo (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
