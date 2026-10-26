import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/tenant_portal.dart';
import 'api_service.dart';
import 'storage_service.dart';

class TenantPortalService extends ChangeNotifier {
  TenantPortalService(this._api, this._storage) {
    _restore();
  }

  final ApiService _api;
  final StorageService _storage;
  TenantPortal? _portal;
  bool _restoring = true;
  bool _loading = false;
  bool _syncingAuthenticatedTenant = false;
  String? _error;

  TenantPortal? get portal => _portal;
  bool get restoring => _restoring;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasTenant => _portal != null;

  Future<void> _restore() async {
    final cached = await _storage.getTenantPortal();
    if (cached != null) {
      try {
        _portal = TenantPortal.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      } catch (_) {
        await _storage.clearTenantPortal();
      }
    }
    _restoring = false;
    notifyListeners();
  }

  Future<bool> selectByCode(String rawCode) async {
    final code = _extractCode(rawCode);
    if (code.isEmpty) {
      _error = 'Ingresa el código de la tienda.';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.get(
        ApiConfig.tenantPortalUrl(code),
        requireAuth: false,
      );
      if (response.statusCode != 200) {
        _error = response.statusCode == 404
            ? 'No existe una tienda activa con ese código.'
            : 'No se pudo abrir esta tienda.';
        return false;
      }
      _portal = TenantPortal.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
      await _storage.saveTenantPortal(jsonEncode(_portal!.toJson()));
      return true;
    } catch (_) {
      _error = _portal == null
          ? 'Sin conexión. Conéctate una vez para validar el código.'
          : 'Sin conexión. Se conservará la última tienda validada.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> syncAuthenticatedTenant() async {
    if (_syncingAuthenticatedTenant || _portal != null) return;
    _syncingAuthenticatedTenant = true;
    try {
      final response = await _api.get(ApiConfig.miEmpresaUrl);
      if (response.statusCode != 200) return;
      final company =
          Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final code = company['codigo']?.toString();
      if (code != null && code.isNotEmpty) await selectByCode(code);
    } catch (_) {
      // Una sesión restaurada puede abrirse offline con el tema predeterminado.
    } finally {
      _syncingAuthenticatedTenant = false;
    }
  }

  String _extractCode(String value) {
    final normalized = value.trim().toLowerCase();
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      final segments = uri.pathSegments;
      final tenantIndex = segments.indexOf('t');
      if (tenantIndex >= 0 && tenantIndex + 1 < segments.length) {
        return segments[tenantIndex + 1];
      }
    }
    return normalized;
  }

  Future<void> usePortal(TenantPortal portal) async {
    _portal = portal;
    _error = null;
    await _storage.saveTenantPortal(jsonEncode(portal.toJson()));
    notifyListeners();
  }

  Future<void> clear() async {
    _portal = null;
    _error = null;
    await _storage.clearTenantPortal();
    notifyListeners();
  }
}
