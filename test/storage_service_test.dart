import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/services/storage_service.dart';

class CorruptedSecureStorage implements SecureStorageStore {
  bool cleared = false;

  @override
  Future<String?> read({required String key}) async {
    throw PlatformException(code: 'read', message: 'BAD_DECRYPT');
  }

  @override
  Future<void> write({required String key, required String? value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {
    cleared = true;
  }
}

class MemorySecureStorage implements SecureStorageStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

void main() {
  test('recupera un almacén cifrado inválido sin bloquear el arranque',
      () async {
    final corrupted = CorruptedSecureStorage();
    final service = StorageService(storage: corrupted);

    expect(await service.getAccessToken(), isNull);
    expect(corrupted.cleared, isTrue);
    expect(await service.getOfflineScope(), 'public');
  });

  test('conserva y elimina tokens válidos', () async {
    final memory = MemorySecureStorage();
    final service = StorageService(storage: memory);

    await service.saveTokens(accessToken: 'access', refreshToken: 'refresh');
    expect(await service.getAccessToken(), 'access');
    expect(await service.getRefreshToken(), 'refresh');

    await service.clearTokens();
    expect(await service.hasToken(), isFalse);
  });
}
