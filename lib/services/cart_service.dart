import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/cart_item.dart';
import 'api_service.dart';

class CartService extends ChangeNotifier {
  final ApiService _apiService;
  List<CartItem> _items = [];
  double _total = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  CartService(this._apiService);

  List<CartItem> get items => _items;
  double get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCart() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get(ApiConfig.carritoUrl, requireAuth: true);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> rawItems = data['items'] ?? [];
        _items = rawItems.map((j) => CartItem.fromJson(j)).toList();
        _total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;
      }
    } catch (e) {
      _errorMessage = 'Error al cargar el carrito.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart({
    required int productoColorId,
    required int tallaId,
    required int sucursalId,
    int cantidad = 1,
    int? stockInventarioId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stockId = stockInventarioId ?? 1;
      final res = await _apiService.post(
        ApiConfig.carritoAgregarUrl,
        body: {
          'stock_inventario_id': stockId,
          'cantidad': cantidad,
        },
        requireAuth: true,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchCart();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          _errorMessage = data['detail'] ?? 'Error (${res.statusCode}): No se pudo agregar al carrito.';
        } catch (_) {
          _errorMessage = 'Error (${res.statusCode}): No se pudo agregar al carrito.';
        }
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> addStockItem(int stockInventarioId, {int cantidad = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.post(
        ApiConfig.carritoAgregarUrl,
        body: {
          'stock_inventario_id': stockInventarioId,
          'cantidad': cantidad,
        },
        requireAuth: true,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchCart();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          _errorMessage = data['detail'] ?? 'Error (${res.statusCode}): No se pudo agregar al carrito.';
        } catch (_) {
          _errorMessage = 'Error (${res.statusCode}): No se pudo agregar al carrito.';
        }
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>?> checkout({
    required String metodoPago,
    double? distanciaKm,
    String? direccionEnvio,
    double? latitudDestino,
    double? longitudDestino,
    String? ubicacionUrl,
    String? ciudad,
    String? referencia,
    int? sucursalId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'metodo_pago': metodoPago,
        if (distanciaKm != null) 'distancia_km': distanciaKm,
        if (direccionEnvio != null && direccionEnvio.isNotEmpty) 'direccion_envio': direccionEnvio,
        if (latitudDestino != null) 'latitud_destino': latitudDestino,
        if (longitudDestino != null) 'longitud_destino': longitudDestino,
        if (ubicacionUrl != null && ubicacionUrl.isNotEmpty) 'ubicacion_url': ubicacionUrl,
        if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
        if (referencia != null && referencia.isNotEmpty) 'referencia': referencia,
        if (sucursalId != null) 'sucursal_id': sucursalId,
      };

      final res = await _apiService.post(
        ApiConfig.carritoCheckoutUrl,
        body: body,
        requireAuth: true,
      );
      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 200) {
        await fetchCart();
        return jsonDecode(res.body);
      }
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> removeItem(int itemId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.delete('${ApiConfig.carritoAgregarUrl}/$itemId', requireAuth: true);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> rawItems = data['items'] ?? [];
        _items = rawItems.map((j) => CartItem.fromJson(j)).toList();
        _total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
    return false;
  }
}
