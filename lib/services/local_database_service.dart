import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  Database? _instance;

  Future<Database> get database async {
    if (_instance != null) return _instance!;
    _instance = await openDatabase(
      path.join(await getDatabasesPath(), 'stylestore_offline.db'),
      version: 2,
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
        await _createOfflineCartTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createOfflineCartTables(db);
        }
      },
    );
    return _instance!;
  }

  static Future<void> _createOfflineCartTables(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS cart_snapshots (scope TEXT PRIMARY KEY, payload TEXT NOT NULL, synced_at TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS local_cart_additions (scope TEXT NOT NULL, stock_id INTEGER NOT NULL, payload TEXT NOT NULL, quantity INTEGER NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY(scope, stock_id))');
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

  Future<({Map<String, dynamic> product, DateTime syncedAt})?>
      findCachedProduct(String scope, int? branchId, String productCode) async {
    final preferred = await loadCatalog(scope, branchId);
    final fallback = branchId == null ? null : await loadCatalog(scope, null);
    for (final snapshot in [preferred, fallback]) {
      if (snapshot == null) continue;
      for (final raw in snapshot.payload) {
        final product = Map<String, dynamic>.from(raw as Map);
        if (product['codigo']?.toString() == productCode) {
          return (product: product, syncedAt: snapshot.syncedAt);
        }
      }
    }
    return null;
  }

  Future<void> saveCartSnapshot(
      String scope, Map<String, dynamic> payload) async {
    await (await database).insert(
      'cart_snapshots',
      {
        'scope': scope,
        'payload': jsonEncode(payload),
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({Map<String, dynamic> payload, DateTime syncedAt})?> loadCartSnapshot(
      String scope) async {
    final rows = await (await database).query(
      'cart_snapshots',
      where: 'scope = ?',
      whereArgs: [scope],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      payload:
          jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>,
      syncedAt: DateTime.parse(rows.first['synced_at'] as String),
    );
  }

  Future<void> addLocalCartItem({
    required String scope,
    required int stockId,
    required int quantity,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'local_cart_additions',
        columns: ['quantity'],
        where: 'scope = ? AND stock_id = ?',
        whereArgs: [scope, stockId],
        limit: 1,
      );
      final previous = existing.isEmpty
          ? 0
          : (existing.first['quantity'] as num?)?.toInt() ?? 0;
      await txn.insert(
        'local_cart_additions',
        {
          'scope': scope,
          'stock_id': stockId,
          'payload': jsonEncode(payload),
          'quantity': previous + quantity,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<Map<String, dynamic>>> loadLocalCartAdditions(
      String scope) async {
    final rows = await (await database).query(
      'local_cart_additions',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return {
        ...payload,
        'stock_inventario_id': row['stock_id'],
        'cantidad': row['quantity'],
      };
    }).toList();
  }

  Future<void> deleteLocalCartAddition(String scope, int stockId) async {
    await (await database).delete(
      'local_cart_additions',
      where: 'scope = ? AND stock_id = ?',
      whereArgs: [scope, stockId],
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

  Future<void> queueProductReview({
    required String operationUuid,
    required String scope,
    required Map<String, dynamic> payload,
  }) async {
    await (await database).insert('sync_queue', {
      'operation_uuid': operationUuid,
      'scope': scope,
      'operation_type': 'resena_producto',
      'payload_version': 1,
      'payload': jsonEncode(payload),
      'client_created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pendiente',
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
      if (typeRows.isNotEmpty &&
          typeRows.first['operation_type'] != 'resena_producto') {
        final table = typeRows.first['operation_type'] == 'reserva'
            ? 'local_reservations'
            : 'local_sales';
        await txn.update(table, {'status': status, 'reason': reason},
            where: 'operation_uuid = ?', whereArgs: [operationUuid]);
      }
    });
  }

  Future<void> saveLocalClient(
      String scope, Map<String, dynamic> client) async {
    final db = await database;
    await db.insert(
      'local_clients',
      {
        'scope': scope,
        'server_code': client['codigo'] ?? client['id']?.toString(),
        'payload': jsonEncode(client),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> loadLocalClients(String scope) async {
    final rows = await (await database).query(
      'local_clients',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    return rows
        .map((row) =>
            jsonDecode(row['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Limpia cachés reconstruibles. Conserva la cola y las adiciones de carrito
  /// todavía no sincronizadas para no perder acciones realizadas sin conexión.
  Future<int> clearScopeCache(String scope) async {
    final db = await database;
    int affected = 0;
    await db.transaction((txn) async {
      affected += await txn
          .delete('catalog_snapshots', where: 'scope = ?', whereArgs: [scope]);
      affected += await txn.delete('authorized_branches',
          where: 'scope = ?', whereArgs: [scope]);
      affected += await txn
          .delete('local_clients', where: 'scope = ?', whereArgs: [scope]);
      affected += await txn
          .delete('cart_snapshots', where: 'scope = ?', whereArgs: [scope]);
    });
    return affected;
  }

  /// Purga de forma segura las operaciones ya resueltas (confirmada, rechazada, conflicto).
  /// Protege estrictamente las operaciones en estado 'pendiente' y 'sincronizando'.
  Future<int> purgeResolvedOperations(String scope) async {
    final db = await database;
    int purgedCount = 0;
    await db.transaction((txn) async {
      final resolvedRows = await txn.query(
        'sync_queue',
        columns: ['operation_uuid'],
        where: 'scope = ? AND status NOT IN (?, ?)',
        whereArgs: [scope, 'pendiente', 'sincronizando'],
      );

      final uuids =
          resolvedRows.map((r) => r['operation_uuid'] as String).toList();
      if (uuids.isEmpty) return;

      for (final uuid in uuids) {
        await txn.delete('local_sale_details',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('local_sales',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('local_reservation_details',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('local_reservations',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('sync_queue',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        purgedCount++;
      }
    });
    return purgedCount;
  }

  /// Elimina snapshots de catálogo y sucursales anteriores a maxAge para prevenir crecimiento desmedido.
  Future<int> purgeExpiredCache(String scope,
      {Duration maxAge = const Duration(days: 7)}) async {
    final db = await database;
    final threshold = DateTime.now().toUtc().subtract(maxAge).toIso8601String();
    int deleted = 0;
    await db.transaction((txn) async {
      deleted += await txn.delete(
        'catalog_snapshots',
        where: 'scope = ? AND synced_at < ?',
        whereArgs: [scope, threshold],
      );
      deleted += await txn.delete(
        'authorized_branches',
        where: 'scope = ? AND synced_at < ?',
        whereArgs: [scope, threshold],
      );
    });
    return deleted;
  }

  /// Determina si existen transacciones pendientes en la cola local para el ámbito dado.
  Future<bool> hasPendingTransactions(String scope) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      columns: ['operation_uuid'],
      where: 'scope = ? AND status = ?',
      whereArgs: [scope, 'pendiente'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Devuelve diagnósticos estructurados del almacenamiento SQLite para el ámbito especificado.
  Future<Map<String, dynamic>> getStorageDiagnostics(String scope) async {
    final db = await database;
    final catalogsCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM catalog_snapshots WHERE scope = ?',
            [scope])) ??
        0;
    final branchesCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM authorized_branches WHERE scope = ?',
            [scope])) ??
        0;
    final clientsCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM local_clients WHERE scope = ?', [scope])) ??
        0;
    final pendingCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE scope = ? AND status = ?',
            [scope, 'pendiente'])) ??
        0;
    final syncingCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE scope = ? AND status = ?',
            [scope, 'sincronizando'])) ??
        0;
    final confirmedCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE scope = ? AND status = ?',
            [scope, 'confirmada'])) ??
        0;
    final conflictCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE scope = ? AND status IN (?, ?)',
            [scope, 'conflicto', 'rechazada'])) ??
        0;
    final pendingCartCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COALESCE(SUM(quantity), 0) FROM local_cart_additions WHERE scope = ?',
            [scope])) ??
        0;

    return {
      'scope': scope,
      'catalogs_count': catalogsCount,
      'branches_count': branchesCount,
      'clients_count': clientsCount,
      'pending_count': pendingCount,
      'syncing_count': syncingCount,
      'confirmed_count': confirmedCount,
      'conflict_count': conflictCount,
      'pending_cart_count': pendingCartCount,
      'total_operations':
          pendingCount + syncingCount + confirmedCount + conflictCount,
    };
  }

  /// Elimina integralmente los datos del ámbito.
  /// Si existen transacciones pendientes y forceEvenIfPending es false, lanza un error para prevenir pérdida de datos.
  Future<void> safeWipeScope(String scope,
      {bool forceEvenIfPending = false}) async {
    final db = await database;
    if (!forceEvenIfPending) {
      final hasPending = await hasPendingTransactions(scope);
      if (hasPending) {
        throw StateError(
            'No se puede purgar el ámbito "$scope" porque contiene operaciones pendientes no sincronizadas. '
            'Sincronice primero o use forceEvenIfPending: true.');
      }
    }
    await db.transaction((txn) async {
      await txn
          .delete('catalog_snapshots', where: 'scope = ?', whereArgs: [scope]);
      await txn.delete('authorized_branches',
          where: 'scope = ?', whereArgs: [scope]);
      await txn.delete('local_clients', where: 'scope = ?', whereArgs: [scope]);
      await txn
          .delete('cart_snapshots', where: 'scope = ?', whereArgs: [scope]);
      await txn.delete('local_cart_additions',
          where: 'scope = ?', whereArgs: [scope]);

      final opRows = await txn.query('sync_queue',
          columns: ['operation_uuid'], where: 'scope = ?', whereArgs: [scope]);
      for (final row in opRows) {
        final uuid = row['operation_uuid'] as String;
        await txn.delete('local_sale_details',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('local_sales',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('local_reservation_details',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
        await txn.delete('local_reservations',
            where: 'operation_uuid = ?', whereArgs: [uuid]);
      }
      await txn.delete('sync_queue', where: 'scope = ?', whereArgs: [scope]);
    });
  }
}
