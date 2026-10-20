import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stylestore_mobile/services/local_database_service.dart';

void main() {
  late String databasePath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databasePath = path.join(await getDatabasesPath(), 'stylestore_offline.db');
  });

  setUp(() async => databaseFactory.deleteDatabase(databasePath));
  tearDown(() async => databaseFactory.deleteDatabase(databasePath));

  test('persiste una reserva y su cola después de reabrir SQLite', () async {
    final first = LocalDatabaseService();
    await first.queueReservation(
      operationUuid: '11111111-1111-4111-8111-111111111111',
      scope: 'empresa-7:usuario-9',
      payload: {
        'sucursal_id': 3,
        'fecha_limite': '2026-10-22',
        'hora_retiro': '15:30:00',
        'items': [
          {'stock_inventario_id': 42, 'cantidad': 1}
        ],
      },
    );
    await first.close();

    final reopened = LocalDatabaseService();
    final pending = await reopened.pendingOperations('empresa-7:usuario-9');
    expect(pending, hasLength(1));
    expect(pending.single['operation_type'], 'reserva');
    expect(pending.single['operation_uuid'],
        '11111111-1111-4111-8111-111111111111');
    expect(await reopened.pendingOperations('empresa-8:usuario-9'), isEmpty);
    await reopened.close();
  });

  test('una venta conserva detalle e importe y respeta el ámbito', () async {
    final service = LocalDatabaseService();
    await service.queueCashSale(
      operationUuid: '22222222-2222-4222-8222-222222222222',
      scope: 'empresa-7:usuario-10',
      payload: {
        'sucursal_id': 3,
        'metodo_pago': 'efectivo',
        'efectivo_recibido': 150,
        'items': [
          {'stock_inventario_id': 52, 'cantidad': 1}
        ],
      },
      total: 120,
      details: [
        {
          'stock_inventario_id': 52,
          'cantidad': 1,
          'precio_unitario': 120,
          'subtotal': 120,
          'producto': 'Chaqueta',
        }
      ],
    );
    final operations = await service.allOperations('empresa-7:usuario-10');
    expect(operations.single['operation_type'], 'venta_efectivo');
    expect(operations.single['status'], 'pendiente');
    expect(await service.allOperations('empresa-7:usuario-11'), isEmpty);
    await service.close();
  });
}
