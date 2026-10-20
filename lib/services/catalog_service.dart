import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/producto.dart';
import 'api_service.dart';
import 'local_database_service.dart';
import 'storage_service.dart';

class CatalogService extends ChangeNotifier {
  final ApiService _apiService;
  final LocalDatabaseService _localDatabase;
  final StorageService _storage;
  List<Producto> _productos = [];
  List<Map<String, dynamic>> _sucursales = [];
  int? _selectedSucursalId;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastSync;
  bool _usingOfflineData = false;

  CatalogService(this._apiService, this._localDatabase, this._storage);

  List<Producto> get productos => _productos;
  List<Map<String, dynamic>> get sucursales => _sucursales;
  int? get selectedSucursalId => _selectedSucursalId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSync => _lastSync;
  bool get usingOfflineData => _usingOfflineData;

  Future<void> fetchSucursales() async {
    try {
      final res =
          await _apiService.get(ApiConfig.sucursalesUrl, requireAuth: false);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        _sucursales = data.map((e) => e as Map<String, dynamic>).toList();
        await _localDatabase.saveBranches(
            await _storage.getOfflineScope(), data);
        notifyListeners();
      }
    } catch (_) {
      _sucursales =
          await _localDatabase.loadBranches(await _storage.getOfflineScope());
      notifyListeners();
    }
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
      String url = ApiConfig.catalogoUrl;
      if (_selectedSucursalId != null) {
        url += '?sucursal_id=$_selectedSucursalId';
      }

      final response = await _apiService.get(url, requireAuth: false);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _productos = data.map((json) => Producto.fromJson(json)).toList();
        await _localDatabase.saveCatalog(
            await _storage.getOfflineScope(), _selectedSucursalId, data);
        _lastSync = DateTime.now();
        _usingOfflineData = false;
      } else {
        _errorMessage = 'Error al cargar catálogo (${response.statusCode})';
      }
    } catch (e) {
      final cached = await _localDatabase.loadCatalog(
          await _storage.getOfflineScope(), _selectedSucursalId);
      if (cached != null) {
        _productos = cached.payload
            .map((item) => Producto.fromJson(item as Map<String, dynamic>))
            .toList();
        _lastSync = cached.syncedAt;
        _usingOfflineData = true;
        _errorMessage = null;
      } else {
        _errorMessage = 'Sin conexión y sin catálogo descargado todavía.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
