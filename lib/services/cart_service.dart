import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/cart_item.dart';
import 'api_service.dart';
import 'local_database_service.dart';
import 'storage_service.dart';

class CartService extends ChangeNotifier {
  final ApiService _apiService;
  final LocalDatabaseService _localDatabase;
  final StorageService _storage;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<CartItem> _items = [];
  double _total = 0.0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _usingOfflineData = false;
  int _pendingLocalItems = 0;

  CartService(this._apiService, this._localDatabase, this._storage) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(fetchCart());
      }
    });
  }

  List<CartItem> get items => _items;
  double get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usingOfflineData => _usingOfflineData;
  int get pendingLocalItems => _pendingLocalItems;

  void resetTenantState() {
    _items = [];
    _total = 0;
    _errorMessage = null;
    _usingOfflineData = false;
    _pendingLocalItems = 0;
    notifyListeners();
  }

  Future<void> fetchCart() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _syncPendingAdditions();
      final res =
          await _apiService.get(ApiConfig.carritoUrl, requireAuth: true);
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final List<dynamic> rawItems = data['items'] ?? [];
        _items = rawItems.map((j) => CartItem.fromJson(j)).toList();
        _total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;
        await _localDatabase.saveCartSnapshot(
            await _storage.getOfflineScope(), data);
        _usingOfflineData = false;
        _pendingLocalItems = 0;
      } else {
        await _loadOfflineCart();
      }
    } catch (_) {
      await _loadOfflineCart();
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
    String? productoNombre,
    String? colorNombre,
    String? tallaNombre,
    String? foto,
    double? precioUnitario,
    String? sucursalNombre,
    String? sucursalCiudad,
    String? sucursalMapsUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stockId = stockInventarioId ?? 1;
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        return await _queueOfflineAddition(
          stockId: stockId,
          productoColorId: productoColorId,
          tallaId: tallaId,
          sucursalId: sucursalId,
          cantidad: cantidad,
          productoNombre: productoNombre,
          colorNombre: colorNombre,
          tallaNombre: tallaNombre,
          foto: foto,
          precioUnitario: precioUnitario,
          sucursalNombre: sucursalNombre,
          sucursalCiudad: sucursalCiudad,
          sucursalMapsUrl: sucursalMapsUrl,
        );
      }
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
          _errorMessage = data['detail'] ??
              'Error (${res.statusCode}): No se pudo agregar al carrito.';
        } catch (_) {
          _errorMessage =
              'Error (${res.statusCode}): No se pudo agregar al carrito.';
        }
      }
    } catch (_) {
      return await _queueOfflineAddition(
        stockId: stockInventarioId ?? 1,
        productoColorId: productoColorId,
        tallaId: tallaId,
        sucursalId: sucursalId,
        cantidad: cantidad,
        productoNombre: productoNombre,
        colorNombre: colorNombre,
        tallaNombre: tallaNombre,
        foto: foto,
        precioUnitario: precioUnitario,
        sucursalNombre: sucursalNombre,
        sucursalCiudad: sucursalCiudad,
        sucursalMapsUrl: sucursalMapsUrl,
      );
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
          _errorMessage = data['detail'] ??
              'Error (${res.statusCode}): No se pudo agregar al carrito.';
        } catch (_) {
          _errorMessage =
              'Error (${res.statusCode}): No se pudo agregar al carrito.';
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
    String? tipoEntrega,
    String? fechaRecojo,
    String? horaRecojo,
    String? codigoDescuento,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'metodo_pago': metodoPago,
        if (distanciaKm != null) 'distancia_km': distanciaKm,
        if (direccionEnvio != null && direccionEnvio.isNotEmpty)
          'direccion_envio': direccionEnvio,
        if (latitudDestino != null) 'latitud_destino': latitudDestino,
        if (longitudDestino != null) 'longitud_destino': longitudDestino,
        if (ubicacionUrl != null && ubicacionUrl.isNotEmpty)
          'ubicacion_url': ubicacionUrl,
        if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
        if (referencia != null && referencia.isNotEmpty)
          'referencia': referencia,
        if (sucursalId != null) 'sucursal_id': sucursalId,
        if (tipoEntrega != null) 'tipo_entrega': tipoEntrega,
        if (fechaRecojo != null) 'fecha_recojo': fechaRecojo,
        if (horaRecojo != null) 'hora_recojo': horaRecojo,
        if (codigoDescuento != null && codigoDescuento.isNotEmpty)
          'codigo_descuento': codigoDescuento,
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

  Future<Map<String, dynamic>?> validateDiscountCode(String code) async {
    try {
      final res = await _apiService.post(
        ApiConfig.validarCodigoDescuentoUrl,
        body: {'codigo': code.trim().toUpperCase(), 'canal': 'online'},
        requireAuth: true,
      );
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      _errorMessage = data['detail']?.toString() ?? 'El código no es válido.';
    } catch (_) {
      _errorMessage = 'No se pudo validar el código.';
    }
    notifyListeners();
    return null;
  }

  Future<bool> removeItem(int itemId) async {
    _isLoading = true;
    notifyListeners();
    if (itemId < 0) {
      await _localDatabase.deleteLocalCartAddition(
          await _storage.getOfflineScope(), -itemId);
      await _loadOfflineCart();
      _isLoading = false;
      notifyListeners();
      return true;
    }
    try {
      final res = await _apiService
          .delete('${ApiConfig.carritoAgregarUrl}/$itemId', requireAuth: true);
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

  Future<bool> _queueOfflineAddition({
    required int stockId,
    required int productoColorId,
    required int tallaId,
    required int sucursalId,
    required int cantidad,
    String? productoNombre,
    String? colorNombre,
    String? tallaNombre,
    String? foto,
    double? precioUnitario,
    String? sucursalNombre,
    String? sucursalCiudad,
    String? sucursalMapsUrl,
  }) async {
    final price = precioUnitario ?? 0;
    final scope = await _storage.getOfflineScope();
    await _localDatabase.addLocalCartItem(
      scope: scope,
      stockId: stockId,
      quantity: cantidad,
      payload: {
        'id': -stockId,
        'stock_inventario_id': stockId,
        'producto_color_id': productoColorId,
        'talla_id': tallaId,
        'sucursal_id': sucursalId,
        'sucursal_nombre': sucursalNombre,
        'sucursal_ciudad': sucursalCiudad,
        'sucursal_maps_url': sucursalMapsUrl,
        'producto_nombre': productoNombre ?? 'Prenda StyleStore',
        'color_nombre': colorNombre,
        'talla_nombre': tallaNombre,
        'foto': foto,
        'precio_unitario': price,
        'subtotal': price * cantidad,
      },
    );
    await _loadOfflineCart();
    _isLoading = false;
    _usingOfflineData = true;
    _errorMessage =
        'Guardado sin conexión. Se añadirá al carrito del servidor al reconectar.';
    notifyListeners();
    return true;
  }

  Future<void> _loadOfflineCart() async {
    final scope = await _storage.getOfflineScope();
    final snapshot = await _localDatabase.loadCartSnapshot(scope);
    final additions = await _localDatabase.loadLocalCartAdditions(scope);
    final rawItems = <dynamic>[
      ...?snapshot?.payload['items'] as List<dynamic>?,
      ...additions.map((item) {
        final quantity = (item['cantidad'] as num?)?.toInt() ?? 1;
        final price =
            double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0;
        return {...item, 'subtotal': price * quantity};
      }),
    ];
    _items = rawItems
        .map(
            (item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _total = _items.fold(0, (sum, item) => sum + item.subtotal);
    _usingOfflineData = true;
    _pendingLocalItems = additions.fold(
        0, (sum, item) => sum + ((item['cantidad'] as num?)?.toInt() ?? 0));
    _errorMessage = snapshot == null && additions.isEmpty
        ? 'Sin conexión y sin carrito guardado todavía.'
        : null;
  }

  Future<void> _syncPendingAdditions() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;
    final scope = await _storage.getOfflineScope();
    final additions = await _localDatabase.loadLocalCartAdditions(scope);
    for (final item in additions) {
      final stockId = (item['stock_inventario_id'] as num).toInt();
      final response = await _apiService.post(
        ApiConfig.carritoAgregarUrl,
        body: {
          'stock_inventario_id': stockId,
          'cantidad': (item['cantidad'] as num?)?.toInt() ?? 1,
        },
        requireAuth: true,
      );
      if (response.statusCode != 200 && response.statusCode != 201) return;
      await _localDatabase.deleteLocalCartAddition(scope, stockId);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
