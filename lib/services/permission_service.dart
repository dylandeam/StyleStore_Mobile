import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../config/api_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

class PermissionService extends ChangeNotifier with WidgetsBindingObserver {
  PermissionService(this._api, this._storage) {
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  final ApiService _api;
  final StorageService _storage;

  Set<String>? _codes;
  int? _empresaId;
  String? _role;
  bool _loading = false;

  int? get empresaId => _empresaId;
  String? get role => _role;
  bool get loading => _loading;
  bool get hasSnapshot => _codes != null;

  bool allows(String code) => _codes?.contains(code) ?? true;

  String unavailableMessage(String code) {
    const messages = {
      'carrito.usar':
          'El carrito no está disponible temporalmente en esta tienda.',
      'ventas.comprar':
          'Las compras no están disponibles temporalmente en esta tienda.',
      'reservas.crear':
          'Las reservas no están disponibles temporalmente en esta tienda.',
      'resenas.crear':
          'Las reseñas no están disponibles temporalmente en esta tienda.',
    };
    return messages[code] ?? 'Esta función no está disponible temporalmente.';
  }

  Future<void> _restore() async {
    final raw = await _storage.getEffectivePermissions();
    if (raw == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _empresaId = (data['empresa_id'] as num?)?.toInt();
      _role = data['role']?.toString();
      _codes = Set<String>.from(
        (data['permission_codes'] as List<dynamic>? ?? const [])
            .map((item) => item.toString()),
      );
      notifyListeners();
    } catch (_) {
      await _storage.clearEffectivePermissions();
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading && !force) return;
    _loading = true;
    notifyListeners();
    try {
      final response = await _api.get(ApiConfig.myPermissionsUrl);
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map,
        );
        _empresaId = (data['empresa_id'] as num?)?.toInt();
        _role = data['role']?.toString();
        _codes = Set<String>.from(
          (data['permission_codes'] as List<dynamic>? ?? const [])
              .map((item) => item.toString()),
        );
        await _storage.saveEffectivePermissions(jsonEncode(data));
      }
    } catch (_) {
      // Offline mode keeps the last known tenant matrix. The backend remains
      // authoritative when queued operations are synchronized.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _codes = null;
    _empresaId = null;
    _role = null;
    await _storage.clearEffectivePermissions();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
