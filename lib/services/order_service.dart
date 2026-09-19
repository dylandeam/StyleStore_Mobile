import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/reserva.dart';
import 'api_service.dart';

class OrderService extends ChangeNotifier {
  final ApiService _apiService;
  List<OrderItem> _orders = [];
  List<ReservaItem> _reservas = [];
  bool _isLoading = false;
  String? _errorMessage;

  OrderService(this._apiService);

  List<OrderItem> get orders => _orders;
  List<ReservaItem> get reservas => _reservas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get(ApiConfig.misComprasUrl, requireAuth: true);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        _orders = list.map((j) => OrderItem.fromJson(j)).toList();
      }
    } catch (e) {
      _errorMessage = 'Error al cargar historial de pedidos.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReservas() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get(ApiConfig.reservasUrl, requireAuth: true);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        _reservas = list.map((j) => ReservaItem.fromJson(j)).toList();
      }
    } catch (e) {
      _errorMessage = 'Error al cargar reservas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmarEntregaEnvio(int envioId) async {
    try {
      final res = await _apiService.patch(
        '${ApiConfig.enviosUrl}/$envioId/confirmar-entrega',
        requireAuth: true,
      );
      if (res.statusCode == 200) {
        await fetchOrders();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> solicitarCambio({
    required int ordenVentaId,
    required int detalleVentaId,
    required String tipo,
    required String motivo,
    required int sucursalId,
    required DateTime fechaProgramada,
    required String descripcionProblema,
  }) async {
    try {
      final res = await _apiService.post(
        ApiConfig.cambiosUrl,
        body: {
          'orden_venta_id': ordenVentaId,
          'detalle_venta_id': detalleVentaId,
          'tipo': tipo,
          'motivo': motivo,
          'sucursal_id': sucursalId,
          'fecha_programada': '${fechaProgramada.year.toString().padLeft(4, '0')}-${fechaProgramada.month.toString().padLeft(2, '0')}-${fechaProgramada.day.toString().padLeft(2, '0')}',
          'descripcion_problema': descripcionProblema,
        },
        requireAuth: true,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
