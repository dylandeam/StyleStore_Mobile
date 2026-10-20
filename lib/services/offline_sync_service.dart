import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'local_database_service.dart';
import 'storage_service.dart';

class OfflineSubmitResult {
  final bool confirmed;
  final bool queued;
  final String operationUuid;
  final String message;

  const OfflineSubmitResult(
      {required this.confirmed,
      required this.queued,
      required this.operationUuid,
      required this.message});
}

class OfflineSyncService extends ChangeNotifier {
  final ApiService _api;
  final LocalDatabaseService _database;
  final StorageService _storage;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _syncing = false;
  int _pendingCount = 0;

  OfflineSyncService(this._api, this._database, this._storage) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) unawaited(syncPending());
    });
    unawaited(refreshPendingCount());
  }

  int get pendingCount => _pendingCount;
  bool get syncing => _syncing;

  Future<OfflineSubmitResult> submitReservation(
      Map<String, dynamic> payload) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.none)) {
      try {
        final response = await _api.post(ApiConfig.reservasUrl,
            body: payload, requireAuth: true);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return const OfflineSubmitResult(
              confirmed: true,
              queued: false,
              operationUuid: '',
              message: 'Reserva confirmada.');
        }
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return OfflineSubmitResult(
            confirmed: false,
            queued: false,
            operationUuid: '',
            message: body['detail']?.toString() ?? 'La reserva fue rechazada.');
      } catch (_) {
        // La pérdida de conexión entre comprobación y envío cae a la cola local.
      }
    }

    final operationUuid = const Uuid().v4();
    await _database.queueReservation(
      operationUuid: operationUuid,
      scope: await _storage.getOfflineScope(),
      payload: payload,
    );
    await refreshPendingCount();
    return OfflineSubmitResult(
      confirmed: false,
      queued: true,
      operationUuid: operationUuid,
      message:
          'Reserva guardada. Se validará el horario y stock al recuperar conexión.',
    );
  }

  Future<OfflineSubmitResult> submitCashSale({
    required Map<String, dynamic> payload,
    required double total,
    required List<Map<String, dynamic>> details,
  }) async {
    if ((payload['metodo_pago'] ?? 'efectivo').toString().toLowerCase() !=
        'efectivo') {
      return const OfflineSubmitResult(
          confirmed: false,
          queued: false,
          operationUuid: '',
          message: 'Sin conexión solo se permiten ventas en efectivo.');
    }
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.none)) {
      try {
        final response = await _api.post(ApiConfig.ventasPresencialUrl,
            body: payload, requireAuth: true);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return const OfflineSubmitResult(
              confirmed: true,
              queued: false,
              operationUuid: '',
              message: 'Venta confirmada.');
        }
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return OfflineSubmitResult(
            confirmed: false,
            queued: false,
            operationUuid: '',
            message: body['detail']?.toString() ?? 'La venta fue rechazada.');
      } catch (_) {}
    }
    final operationUuid = const Uuid().v4();
    await _database.queueCashSale(
      operationUuid: operationUuid,
      scope: await _storage.getOfflineScope(),
      payload: payload,
      total: total,
      details: details,
    );
    await refreshPendingCount();
    return OfflineSubmitResult(
      confirmed: false,
      queued: true,
      operationUuid: operationUuid,
      message:
          'Venta cobrada y guardada provisionalmente. Se validará el stock al reconectar.',
    );
  }

  Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      final scope = await _storage.getOfflineScope();
      for (final operation in await _database.pendingOperations(scope)) {
        try {
          final response = await _api.post(
            ApiConfig.syncOperationsUrl,
            body: {
              'operation_uuid': operation['operation_uuid'],
              'operation_type': operation['operation_type'],
              'payload_version': operation['payload_version'],
              'client_created_at': operation['client_created_at'],
              'payload': jsonDecode(operation['payload'] as String),
            },
            requireAuth: true,
          );
          if (response.statusCode != 200) break;
          final result = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          final status = result['status'] == 'procesando'
              ? 'pendiente'
              : result['status'].toString();
          await _database.updateOperation(
            operation['operation_uuid'] as String,
            status,
            reason: result['reason']?.toString(),
            resultId: result['result_id'] as int?,
          );
        } catch (_) {
          break;
        }
      }
    } finally {
      _syncing = false;
      await refreshPendingCount();
      notifyListeners();
    }
  }

  Future<void> refreshPendingCount() async {
    _pendingCount =
        (await _database.pendingOperations(await _storage.getOfflineScope()))
            .length;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> operations() async {
    return _database.allOperations(await _storage.getOfflineScope());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
