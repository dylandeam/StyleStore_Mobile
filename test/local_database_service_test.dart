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

  test('aislamiento y persistencia de clientes locales por ámbito', () async {
    final service = LocalDatabaseService();
    await service.saveLocalClient('empresa-1:usuario-10', {
      'codigo': 'CLI-001',
      'nombre': 'Carlos Pérez',
      'telefono': '70012345',
    });
    await service.saveLocalClient('empresa-2:usuario-20', {
      'codigo': 'CLI-002',
      'nombre': 'Ana Gomez',
      'telefono': '71122334',
    });

    final clients1 = await service.loadLocalClients('empresa-1:usuario-10');
    expect(clients1, hasLength(1));
    expect(clients1.single['nombre'], 'Carlos Pérez');

    final clients2 = await service.loadLocalClients('empresa-2:usuario-20');
    expect(clients2, hasLength(1));
    expect(clients2.single['nombre'], 'Ana Gomez');

    expect(await service.loadLocalClients('empresa-3:usuario-99'), isEmpty);
    await service.close();
  });

  test(
      'clearScopeCache elimina snapshots y clientes pero preserva la cola de transacciones',
      () async {
    final service = LocalDatabaseService();
    const scope = 'empresa-9:usuario-15';

    // 1. Guardar caché de catálogo y clientes
    await service.saveCatalog(scope, 1, [
      {'id': 101, 'nombre': 'Polera'}
    ]);
    await service.saveBranches(scope, [
      {'id': 1, 'nombre': 'Central'}
    ]);
    await service
        .saveLocalClient(scope, {'codigo': 'CLI-TEST', 'nombre': 'Juan'});

    // 2. Encolar una transacción pendiente
    await service.queueReservation(
      operationUuid: '33333333-3333-4333-8333-333333333333',
      scope: scope,
      payload: {
        'sucursal_id': 1,
        'fecha_limite': '2026-10-23',
        'hora_retiro': '16:00:00',
        'items': [
          {'stock_inventario_id': 1, 'cantidad': 1}
        ],
      },
    );

    // 3. Ejecutar limpieza segura de caché
    final affected = await service.clearScopeCache(scope);
    expect(affected, greaterThanOrEqualTo(3));

    // 4. Verificar que catálogo y clientes están vacíos
    expect(await service.loadCatalog(scope, 1), isNull);
    expect(await service.loadBranches(scope), isEmpty);
    expect(await service.loadLocalClients(scope), isEmpty);

    // 5. Verificar que la cola de transacciones pendientes SIGUE INTACTA
    final pending = await service.pendingOperations(scope);
    expect(pending, hasLength(1));
    expect(pending.single['operation_uuid'],
        '33333333-3333-4333-8333-333333333333');
    expect(pending.single['status'], 'pendiente');

    await service.close();
  });

  test(
      'purgeResolvedOperations elimina operaciones resueltas pero protege las pendientes',
      () async {
    final service = LocalDatabaseService();
    const scope = 'empresa-9:usuario-20';

    // Encolar 2 operaciones
    await service.queueReservation(
      operationUuid: '44444444-4444-4444-8444-444444444444',
      scope: scope,
      payload: {
        'sucursal_id': 1,
        'fecha_limite': '2026-10-23',
        'hora_retiro': '16:00:00',
        'items': [
          {'stock_inventario_id': 1, 'cantidad': 1}
        ],
      },
    );
    await service.queueCashSale(
      operationUuid: '55555555-5555-4555-8555-555555555555',
      scope: scope,
      payload: {
        'sucursal_id': 1,
        'metodo_pago': 'efectivo',
        'efectivo_recibido': 100,
        'items': [
          {'stock_inventario_id': 1, 'cantidad': 1}
        ],
      },
      total: 80,
      details: [
        {
          'stock_inventario_id': 1,
          'cantidad': 1,
          'precio_unitario': 80,
          'subtotal': 80,
          'producto': 'Jean'
        }
      ],
    );

    // Marcar la venta como 'confirmada'
    await service.updateOperation(
        '55555555-5555-4555-8555-555555555555', 'confirmada',
        resultId: 1001);

    // Purgar resueltas
    final purged = await service.purgeResolvedOperations(scope);
    expect(purged, 1);

    // La operación pendiente se mantiene intacta
    final remaining = await service.allOperations(scope);
    expect(remaining, hasLength(1));
    expect(remaining.single['operation_uuid'],
        '44444444-4444-4444-8444-444444444444');
    expect(remaining.single['status'], 'pendiente');

    await service.close();
  });

  test(
      'diagnósticos y safeWipeScope protegen transacciones pendientes de borrado accidental',
      () async {
    final service = LocalDatabaseService();
    const scope = 'empresa-5:usuario-30';

    await service.queueReservation(
      operationUuid: '66666666-6666-4666-8666-666666666666',
      scope: scope,
      payload: {
        'sucursal_id': 2,
        'fecha_limite': '2026-10-24',
        'hora_retiro': '10:00:00',
        'items': [
          {'stock_inventario_id': 5, 'cantidad': 2}
        ],
      },
    );

    final diag = await service.getStorageDiagnostics(scope);
    expect(diag['scope'], scope);
    expect(diag['pending_count'], 1);
    expect(diag['total_operations'], 1);
    expect(await service.hasPendingTransactions(scope), isTrue);

    // safeWipeScope sin forzar DEBE arrojar error por contener operaciones pendientes
    await expectLater(service.safeWipeScope(scope), throwsA(isA<StateError>()));

    // safeWipeScope forzado permite limpiar completamente
    await service.safeWipeScope(scope, forceEvenIfPending: true);
    expect(await service.allOperations(scope), isEmpty);
    expect(await service.hasPendingTransactions(scope), isFalse);

    await service.close();
  });

  test('detalle de producto se recupera del catálogo SQLite por ámbito',
      () async {
    final service = LocalDatabaseService();
    const scope = 'empresa-2:usuario-6';
    await service.saveCatalog(scope, 7, [
      {
        'codigo': 'PROD-0001',
        'nombre': 'Polo',
        'foto': '/uploads/polo.jpg',
        'variantes': [
          {
            'producto_color_id': 10,
            'existencias': [
              {
                'stock_inventario_id': 55,
                'talla_id': 3,
                'sucursal_id': 7,
                'cantidad': 5,
              }
            ]
          }
        ]
      }
    ]);

    final cached = await service.findCachedProduct(scope, 7, 'PROD-0001');
    expect(cached, isNotNull);
    expect(cached!.product['nombre'], 'Polo');
    expect(cached.product['variantes'], isNotEmpty);
    expect(
        await service.findCachedProduct('empresa-99:usuario-6', 7, 'PROD-0001'),
        isNull);
    await service.close();
  });

  test('carrito offline persiste adiciones y las aísla por tenant y usuario',
      () async {
    final first = LocalDatabaseService();
    const scope = 'empresa-2:usuario-6';
    await first.saveCartSnapshot(scope, {
      'items': [
        {
          'id': 9,
          'stock_inventario_id': 40,
          'producto_color_id': 8,
          'talla_id': 2,
          'sucursal_id': 7,
          'producto_nombre': 'Camisa',
          'precio_unitario': 80,
          'cantidad': 1,
          'subtotal': 80,
        }
      ],
      'total': 80,
    });
    await first.addLocalCartItem(
      scope: scope,
      stockId: 55,
      quantity: 1,
      payload: {
        'id': -55,
        'producto_color_id': 10,
        'talla_id': 3,
        'sucursal_id': 7,
        'producto_nombre': 'Polo',
        'precio_unitario': 70,
        'subtotal': 70,
      },
    );
    await first.addLocalCartItem(
      scope: scope,
      stockId: 55,
      quantity: 2,
      payload: {
        'id': -55,
        'producto_color_id': 10,
        'talla_id': 3,
        'sucursal_id': 7,
        'producto_nombre': 'Polo',
        'precio_unitario': 70,
        'subtotal': 70,
      },
    );
    await first.close();

    final reopened = LocalDatabaseService();
    final snapshot = await reopened.loadCartSnapshot(scope);
    final additions = await reopened.loadLocalCartAdditions(scope);
    expect(snapshot, isNotNull);
    expect(snapshot!.payload['total'], 80);
    expect(additions, hasLength(1));
    expect(additions.single['cantidad'], 3);
    expect(
        await reopened.loadLocalCartAdditions('empresa-3:usuario-6'), isEmpty);
    final diagnostics = await reopened.getStorageDiagnostics(scope);
    expect(diagnostics['pending_cart_count'], 3);
    await reopened.deleteLocalCartAddition(scope, 55);
    expect(await reopened.loadLocalCartAdditions(scope), isEmpty);
    await reopened.close();
  });
}
