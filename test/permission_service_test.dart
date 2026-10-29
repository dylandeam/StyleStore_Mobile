import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stylestore_mobile/services/api_service.dart';
import 'package:stylestore_mobile/services/permission_service.dart';
import 'package:stylestore_mobile/services/storage_service.dart';

class _MemoryStore implements SecureStorageStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

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
}

class _ApiStub extends ApiService {
  _ApiStub(super.storage);

  Map<String, dynamic> response = {
    'empresa_id': 7,
    'role': 'cliente',
    'permission_codes': ['catalogo.ver', 'reservas.crear'],
  };

  @override
  Future<http.Response> get(String url, {bool requireAuth = true}) async =>
      http.Response(jsonEncode(response), 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps a tenant permission snapshot and refreshes it from backend',
      () async {
    final store = _MemoryStore();
    final storage = StorageService(storage: store);
    final api = _ApiStub(storage);
    final service = PermissionService(api, storage);

    await service.refresh();
    expect(service.empresaId, 7);
    expect(service.role, 'cliente');
    expect(service.allows('reservas.crear'), isTrue);
    expect(service.allows('ventas.comprar'), isFalse);
    expect(
      service.unavailableMessage('ventas.comprar'),
      'Las compras no están disponibles temporalmente en esta tienda.',
    );

    api.response = {
      'empresa_id': 7,
      'role': 'cliente',
      'permission_codes': ['catalogo.ver', 'ventas.comprar'],
    };
    await service.refresh(force: true);
    expect(service.allows('ventas.comprar'), isTrue);
    expect(service.allows('reservas.crear'), isFalse);
    service.dispose();
  });
}
