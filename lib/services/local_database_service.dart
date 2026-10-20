import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  Database? _instance;

  Future<Database> get database async {
    if (_instance != null) return _instance!;
    _instance = await openDatabase(
      path.join(await getDatabasesPath(), 'stylestore_offline.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE catalog_snapshots (scope TEXT NOT NULL, branch_key TEXT NOT NULL, payload TEXT NOT NULL, synced_at TEXT NOT NULL, PRIMARY KEY(scope, branch_key))');
        await db.execute(
            'CREATE TABLE authorized_branches (scope TEXT NOT NULL, server_id INTEGER NOT NULL, payload TEXT NOT NULL, synced_at TEXT NOT NULL, PRIMARY KEY(scope, server_id))');
        await db.execute(
            'CREATE TABLE local_clients (id INTEGER PRIMARY KEY AUTOINCREMENT, scope TEXT NOT NULL, server_code TEXT, payload TEXT NOT NULL, UNIQUE(scope, server_code))');
        await db.execute(
            'CREATE TABLE local_sales (operation_uuid TEXT PRIMARY KEY, scope TEXT NOT NULL, branch_id INTEGER NOT NULL, total REAL NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, reason TEXT)');
        await db.execute(
            'CREATE TABLE local_sale_details (id INTEGER PRIMARY KEY AUTOINCREMENT, operation_uuid TEXT NOT NULL, stock_id INTEGER NOT NULL, quantity INTEGER NOT NULL, unit_price REAL NOT NULL, subtotal REAL NOT NULL, payload TEXT NOT NULL, FOREIGN KEY(operation_uuid) REFERENCES local_sales(operation_uuid) ON DELETE CASCADE)');
        await db.execute(
            'CREATE TABLE local_reservations (operation_uuid TEXT PRIMARY KEY, scope TEXT NOT NULL, branch_id INTEGER NOT NULL, pickup_date TEXT NOT NULL, pickup_time TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, reason TEXT)');
        await db.execute(
            'CREATE TABLE local_reservation_details (id INTEGER PRIMARY KEY AUTOINCREMENT, operation_uuid TEXT NOT NULL, stock_id INTEGER NOT NULL, quantity INTEGER NOT NULL, FOREIGN KEY(operation_uuid) REFERENCES local_reservations(operation_uuid) ON DELETE CASCADE)');
        await db.execute(
            'CREATE TABLE sync_queue (operation_uuid TEXT PRIMARY KEY, scope TEXT NOT NULL, operation_type TEXT NOT NULL, payload_version INTEGER NOT NULL, payload TEXT NOT NULL, client_created_at TEXT NOT NULL, status TEXT NOT NULL, reason TEXT, result_id INTEGER)');
        await db.execute(
            'CREATE INDEX ix_sync_queue_scope_status ON sync_queue(scope, status)');
      },
    );
    return _instance!;
  }

  Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  Future<void> saveCatalog(
      String scope, int? branchId, List<dynamic> payload) async {
    await (await database).insert(
        'catalog_snapshots',
        {
          'scope': scope,
          'branch_key': branchId?.toString() ?? 'all',
          'payload': jsonEncode(payload),
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<({List<dynamic> payload, DateTime syncedAt})?> loadCatalog(
      String scope, int? branchId) async {
    final rows = await (await database).query('catalog_snapshots',
        where: 'scope = ? AND branch_key = ?',
        whereArgs: [scope, branchId?.toString() ?? 'all'],
        limit: 1);
    if (rows.isEmpty) return null;
    return (
      payload: jsonDecode(rows.first['payload'] as String) as List<dynamic>,
      syncedAt: DateTime.parse(rows.first['synced_at'] as String)
    );
  }

  Future<void> saveBranches(String scope, List<dynamic> branches) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('authorized_branches',
          where: 'scope = ?', whereArgs: [scope]);
      for (final item in branches.cast<Map<String, dynamic>>()) {
        await txn.insert('authorized_branches', {
          'scope': scope,
          'server_id': item['id'],
          'payload': jsonEncode(item),
          'synced_at': DateTime.now().toUtc().toIso8601String()
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadBranches(String scope) async {
    final rows = await (await database)
        .query('authorized_branches', where: 'scope = ?', whereArgs: [scope]);
    return rows
        .map((row) =>
            jsonDecode(row['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> stockOptions(String scope) async {
    final rows = await (await database).query('catalog_snapshots',
        where: 'scope = ?', whereArgs: [scope], orderBy: 'synced_at DESC');
    final options = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      for (final product in (jsonDecode(row['payload'] as String) as List)
          .cast<Map<String, dynamic>>()) {
        for (final variant in (product['variantes'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          for (final stock in (variant['existencias'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final id = stock['stock_inventario_id'] as int?;
            if (id == null || options.containsKey(id)) continue;
            options[id] = {
              'stock_inventario_id': id,
              'producto': product['nombre'] ?? product['codigo'],
              'precio': double.tryParse(product['precio'].toString()) ?? 0,
              'color': variant['color_nombre'] ?? '',
              'talla': stock['talla_nombre'] ?? '',
              'sucursal_id': stock['sucursal_id'],
              'sucursal': stock['sucursal_nombre'] ?? '',
              'cantidad': stock['cantidad'] ?? 0,
            };
          }
        }
      }
    }
    return options.values
        .where((item) => (item['cantidad'] as num) > 0)
        .toList();
  }

  Future<void> queueReservation({
    required String operationUuid,
    required String scope,
    required Map<String, dynamic> payload,
  }) async {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('local_reservations', {
        'operation_uuid': operationUuid,
        'scope': scope,
        'branch_id': payload['sucursal_id'],
        'pickup_date': payload['fecha_limite'],
        'pickup_time': payload['hora_retiro'],
        'status': 'pendiente',
        'created_at': createdAt,
      });
      for (final item
          in (payload['items'] as List).cast<Map<String, dynamic>>()) {
        await txn.insert('local_reservation_details', {
          'operation_uuid': operationUuid,
          'stock_id': item['stock_inventario_id'],
          'quantity': item['cantidad'],
        });
      }
      await txn.insert('sync_queue', {
        'operation_uuid': operationUuid,
        'scope': scope,
        'operation_type': 'reserva',
        'payload_version': 1,
        'payload': jsonEncode(payload),
        'client_created_at': createdAt,
        'status': 'pendiente',
      });
    });
  }

  Future<void> queueCashSale({
    required String operationUuid,
    required String scope,
    required Map<String, dynamic> payload,
    required double total,
    required List<Map<String, dynamic>> details,
  }) async {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('local_sales', {
        'operation_uuid': operationUuid,
        'scope': scope,
        'branch_id': payload['sucursal_id'],
        'total': total,
        'status': 'pendiente',
        'created_at': createdAt,
      });
      for (final item in details) {
        await txn.insert('local_sale_details', {
          'operation_uuid': operationUuid,
          'stock_id': item['stock_inventario_id'],
          'quantity': item['cantidad'],
          'unit_price': item['precio_unitario'],
          'subtotal': item['subtotal'],
          'payload': jsonEncode(item),
        });
      }
      await txn.insert('sync_queue', {
        'operation_uuid': operationUuid,
        'scope': scope,
        'operation_type': 'venta_efectivo',
        'payload_version': 1,
        'payload': jsonEncode({
          ...payload,
          'snapshot': {'total': total, 'items': details}
        }),
        'client_created_at': createdAt,
        'status': 'pendiente',
      });
    });
  }

  Future<List<Map<String, dynamic>>> pendingOperations(String scope) async {
    return (await database).query(
      'sync_queue',
      where: 'scope = ? AND status = ?',
      whereArgs: [scope, 'pendiente'],
      orderBy: 'client_created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> allOperations(String scope) async {
    return (await database).query(
      'sync_queue',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'client_created_at DESC',
    );
  }

  Future<void> updateOperation(
    String operationUuid,
    String status, {
    String? reason,
    int? resultId,
  }) async {
    final values = <String, Object?>{'status': status, 'reason': reason};
    if (resultId != null) values['result_id'] = resultId;
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('sync_queue', values,
          where: 'operation_uuid = ?', whereArgs: [operationUuid]);
      final typeRows = await txn.query('sync_queue',
          columns: ['operation_type'],
          where: 'operation_uuid = ?',
          whereArgs: [operationUuid],
          limit: 1);
      if (typeRows.isNotEmpty) {
        final table = typeRows.first['operation_type'] == 'reserva'
            ? 'local_reservations'
            : 'local_sales';
        await txn.update(table, {'status': status, 'reason': reason},
            where: 'operation_uuid = ?', whereArgs: [operationUuid]);
      }
    });
  }
}
