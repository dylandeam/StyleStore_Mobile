import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorageStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String? value});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

class FlutterSecureStorageStore implements SecureStorageStore {
  const FlutterSecureStorageStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class StorageService {
  StorageService({SecureStorageStore? storage})
      : _storage = storage ?? const FlutterSecureStorageStore();

  final SecureStorageStore _storage;

  static const String _keyAccessToken = 'stylestore_access_token';
  static const String _keyRefreshToken = 'stylestore_refresh_token';
  static const String _keyDeviceId = 'stylestore_device_id';
  static const String _keyPushRegistration = 'stylestore_push_registration';
  static const String _keyTenantPortal = 'stylestore_tenant_portal';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return _readSafely(_keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _readSafely(_keyRefreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getDeviceId() => _readSafely(_keyDeviceId);

  Future<void> saveDeviceId(String value) =>
      _storage.write(key: _keyDeviceId, value: value);

  Future<String?> getPushRegistration() => _readSafely(_keyPushRegistration);

  Future<void> savePushRegistration(String value) =>
      _storage.write(key: _keyPushRegistration, value: value);

  Future<void> clearPushRegistration() =>
      _storage.delete(key: _keyPushRegistration);

  Future<String?> getTenantPortal() => _readSafely(_keyTenantPortal);

  Future<void> saveTenantPortal(String value) =>
      _storage.write(key: _keyTenantPortal, value: value);

  Future<void> clearTenantPortal() => _storage.delete(key: _keyTenantPortal);

  Future<String?> _readSafely(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      // Android puede restaurar preferencias cifradas sin la clave del Keystore
      // después de reinstalar la app. Esos valores no son recuperables: limpiar el
      // almacén permite volver al login en vez de bloquear el arranque para siempre.
      try {
        await _storage.deleteAll();
      } on PlatformException {
        // Si el plugin tampoco puede limpiar, el valor se trata como inexistente.
      }
      return null;
    }
  }

  Future<String> getOfflineScope() async {
    final token = await getAccessToken();
    if (token == null) return 'public';
    try {
      final parts = token.split('.');
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return 'empresa-${payload['empresa_id'] ?? 'none'}:usuario-${payload['sub'] ?? 'unknown'}';
    } catch (_) {
      return 'session-unknown';
    }
  }
}
