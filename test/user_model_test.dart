import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/models/user.dart';

void main() {
  group('User Model Unit Tests', () {
    test('User fromJson parses correctly', () {
      final json = {
        'id': 1,
        'empresa_id': 10,
        'sucursal_id': 2,
        'email': 'user@example.com',
        'name': 'Juan Pérez',
        'is_active': true,
        'created_at': '2026-09-01T12:00:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.empresaId, 10);
      expect(user.sucursalId, 2);
      expect(user.email, 'user@example.com');
      expect(user.name, 'Juan Pérez');
      expect(user.isActive, true);
      expect(user.createdAt, DateTime.parse('2026-09-01T12:00:00.000Z'));
    });

    test('User toJson serializes correctly', () {
      final user = User(
        id: 2,
        empresaId: 10,
        sucursalId: 3,
        email: 'maria@example.com',
        name: 'María Gómez',
        isActive: true,
        createdAt: DateTime.parse('2026-09-01T15:30:00.000Z'),
      );

      final json = user.toJson();

      expect(json['id'], 2);
      expect(json['empresa_id'], 10);
      expect(json['sucursal_id'], 3);
      expect(json['email'], 'maria@example.com');
      expect(json['name'], 'María Gómez');
      expect(json['is_active'], true);
    });
  });
}
