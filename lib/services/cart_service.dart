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
  }) async {
    try {
      final res = await _apiService.post(
        ApiConfig.carritoAgregarUrl,
        body: {
          'producto_color_id': productoColorId,
          'talla_id': tallaId,
          'sucursal_id': sucursalId,
          'cantidad': cantidad,
        },
        requireAuth: true,
      );
      if (res.statusCode == 200) {
        await fetchCart();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> checkout({
    required String metodoPago,
    double? distanciaKm,
    String? direccionEnvio,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _apiService.post(
        ApiConfig.carritoCheckoutUrl,
        body: {
          'metodo_pago': metodoPago,
          'distancia_km': distanciaKm,
          'direccion_envio': direccionEnvio,
        },
        requireAuth: true,
      );
      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 200) {
        await fetchCart();
        return jsonDecode(res.body);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }
}
