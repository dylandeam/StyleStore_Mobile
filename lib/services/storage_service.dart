import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyAccessToken = 'stylestore_access_token';
  static const String _keyRefreshToken = 'stylestore_refresh_token';
  static const String _keyDeviceId = 'stylestore_device_id';
  static const String _keyPushRegistration = 'stylestore_push_registration';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getDeviceId() => _storage.read(key: _keyDeviceId);

  Future<void> saveDeviceId(String value) =>
      _storage.write(key: _keyDeviceId, value: value);

  Future<String?> getPushRegistration() =>
      _storage.read(key: _keyPushRegistration);

  Future<void> savePushRegistration(String value) =>
      _storage.write(key: _keyPushRegistration, value: value);

  Future<void> clearPushRegistration() =>
      _storage.delete(key: _keyPushRegistration);

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
