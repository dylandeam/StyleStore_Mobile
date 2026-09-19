import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/producto.dart';
import 'api_service.dart';

class CatalogService extends ChangeNotifier {
  final ApiService _apiService;
  List<Producto> _productos = [];
  List<Map<String, dynamic>> _sucursales = [];
  int? _selectedSucursalId;
  bool _isLoading = false;
  String? _errorMessage;

  CatalogService(this._apiService);

  List<Producto> get productos => _productos;
  List<Map<String, dynamic>> get sucursales => _sucursales;
  int? get selectedSucursalId => _selectedSucursalId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSucursales() async {
    try {
      final res = await _apiService.get(ApiConfig.sucursalesUrl, requireAuth: true);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        _sucursales = data.map((e) => e as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  void setSucursal(int? sucursalId) {
    _selectedSucursalId = sucursalId;
    fetchCatalog();
  }

  Future<void> fetchCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String url = '${ApiConfig.baseUrl}/productos';
      if (_selectedSucursalId != null) {
        url += '?sucursal_id=$_selectedSucursalId';
      }

      final response = await _apiService.get(url, requireAuth: true);

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
