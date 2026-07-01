import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/production_record_model.dart';
import '../models/product_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  // 数据库版本号，用于未来升级
  static const int _databaseVersion = 4;
  static const String _recordSelectColumns = '''
        pr.id,
        pr.productId,
        p.productType,
        p.productCode,
        pr.quantity,
        pr.date,
        pr.operatorId,
        pr.notes,
        pr.isRework,
        pr.clientUuid,
        pr.serverId,
        pr.syncStatus,
        pr.lastSyncAt,
        pr.syncError,
        pr.retryCount,
        pr.deletedAt,
        pr.updatedAt
      ''';

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('production_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        // 启用外键约束
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _createTables(db);
    await _createIndexes(db);
    await _ensureDeviceId(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 示例：从版本1升级到版本2的迁移逻辑
      await db.execute(
          'ALTER TABLE products ADD COLUMN isActive INTEGER DEFAULT 1');
    }
    if (oldVersion < 3) {
      // 从版本2升级到版本3：添加isRework字段
      await _addColumnIfMissing(
          db, 'production_records', 'isRework', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await _createMetadataTable(db);
      await _addSyncColumns(db);
      await _backfillSyncFields(db);
      await _createIndexes(db);
      await _ensureDeviceId(db);
    }
  }

  Future<void> _createTables(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const boolType = 'INTEGER NOT NULL'; // SQLite用0/1表示布尔值

    await db.execute('''
      CREATE TABLE products (
        id $idType,
        productType $textType,
        productCode $textType,
        description $textNullable,
        price $realType DEFAULT 0.0,
        isActive $boolType DEFAULT 1,
        createdAt $textType DEFAULT (datetime('now','localtime')),
        UNIQUE(productType, productCode)
      )
    ''');

    await db.execute('''
      CREATE TABLE production_records (
        id $idType,
        productId $integerType,
        date $textType,
        quantity $integerType,
        isRework $boolType DEFAULT 0,
        clientUuid $textType,
        serverId $textNullable,
        syncStatus $textType DEFAULT 'pending',
        lastSyncAt $textNullable,
        syncError $textNullable,
        retryCount $integerType DEFAULT 0,
        deletedAt $textNullable,
        updatedAt $textType DEFAULT (datetime('now','localtime')),
        operatorId INTEGER,
        notes $textNullable,
        recordedAt $textType DEFAULT (datetime('now','localtime')),
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await _createMetadataTable(db);
  }

  Future<void> _createIndexes(Database db) async {
    // 产品表索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_productCode ON products(productCode)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_isActive ON products(isActive)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_productType_productCode ON products(productType, productCode)');

    // 生产记录表索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_production_records_productId ON production_records(productId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_production_records_date ON production_records(date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_production_records_productId_date ON production_records(productId, date)');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_production_records_clientUuid ON production_records(clientUuid)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_production_records_syncStatus ON production_records(syncStatus)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_production_records_deletedAt ON production_records(deletedAt)');
  }

  Future<void> _createMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<bool> _hasColumn(Database db, String table, String column) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((row) => row['name'] == column);
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    if (!await _hasColumn(db, table, column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _addSyncColumns(Database db) async {
    await _addColumnIfMissing(db, 'production_records', 'clientUuid', 'TEXT');
    await _addColumnIfMissing(db, 'production_records', 'serverId', 'TEXT');
    await _addColumnIfMissing(
        db, 'production_records', 'syncStatus', "TEXT DEFAULT 'pending'");
    await _addColumnIfMissing(db, 'production_records', 'lastSyncAt', 'TEXT');
    await _addColumnIfMissing(db, 'production_records', 'syncError', 'TEXT');
    await _addColumnIfMissing(
        db, 'production_records', 'retryCount', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'production_records', 'deletedAt', 'TEXT');
    await _addColumnIfMissing(db, 'production_records', 'updatedAt', 'TEXT');
  }

  Future<void> _backfillSyncFields(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate('''
      UPDATE production_records
      SET
        clientUuid = COALESCE(clientUuid, 'legacy-' || id),
        syncStatus = COALESCE(syncStatus, 'pending'),
        retryCount = COALESCE(retryCount, 0),
        updatedAt = COALESCE(updatedAt, recordedAt, date, ?)
      WHERE clientUuid IS NULL
         OR syncStatus IS NULL
         OR retryCount IS NULL
         OR updatedAt IS NULL
    ''', [now]);
  }

  String _createClientUuid() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = List.generate(
            4, (_) => random.nextInt(1 << 16).toRadixString(16).padLeft(4, '0'))
        .join();
    return 'local-$timestamp-$suffix';
  }

  Future<String> _ensureDeviceId(Database db) async {
    await _createMetadataTable(db);
    final rows = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: ['deviceId'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first['value'] as String;
    }

    final deviceId = 'device-${_createClientUuid()}';
    await db.insert(
      'app_metadata',
      {'key': 'deviceId', 'value': deviceId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return deviceId;
  }

  Future<String> getDeviceId() async {
    final db = await database;
    return _ensureDeviceId(db);
  }

  // 产品操作
  Future<Product> createProduct(Product product) async {
    final db = await instance.database;
    final id = await db.insert('products', product.toMap());
    return product.copy(id: id);
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<Product?> getProduct(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? Product.fromMap(maps.first) : null;
  }

  Future<Product?> getProductByCode(
      String productCode, ProductType productType) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      where: 'productCode = ? AND productType = ?',
      whereArgs: [productCode, productTypeDisplayNames[productType]],
      limit: 1,
    );
    return maps.isNotEmpty ? Product.fromMap(maps.first) : null;
  }

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: activeOnly ? 'isActive = 1' : null,
      orderBy: 'productCode ASC',
    );
    return result.map(Product.fromMap).toList();
  }

  // 生产记录操作
  Future<ProductionRecord> createProductionRecord(
      ProductionRecord record) async {
    final db = await instance.database;
    final now = DateTime.now();
    final syncReadyRecord = record.copy(
      clientUuid: record.clientUuid ?? _createClientUuid(),
      syncStatus: SyncStatus.pending,
      retryCount: 0,
      updatedAt: now,
    );
    final id = await db.insert('production_records', syncReadyRecord.toMap());
    return syncReadyRecord.copy(id: id);
  }

  /// 删除生产记录
  Future<bool> deleteProductionRecord(int recordId) async {
    final db = await instance.database;
    try {
      final now = DateTime.now().toIso8601String();
      final result = await db.update(
        'production_records',
        {
          'deletedAt': now,
          'updatedAt': now,
          'syncStatus': SyncStatus.deletedPending.name,
          'syncError': null,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );
      return result > 0;
    } catch (e) {
      debugPrint('删除生产记录出错: $e');
      return false;
    }
  }

  Future<List<ProductionRecord>> getProductionRecordsByProduct(int productId,
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;

    final where = StringBuffer('pr.productId = ?');
    final whereArgs = <dynamic>[productId];

    if (startDate != null) {
      where.write(' AND date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.write(' AND date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    where.write(' AND pr.deletedAt IS NULL');

    final result = await db.rawQuery('''
      SELECT $_recordSelectColumns
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE ${where.toString()}
      ORDER BY pr.date DESC
    ''', whereArgs);

    return result.map(ProductionRecord.fromMap).toList();
  }

  Future<List<ProductionRecord>> getProductionRecordsByDate(
      DateTime date) async {
    final db = await instance.database;
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    try {
      final result = await db.rawQuery('''
      SELECT 
        $_recordSelectColumns
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date >= ? AND pr.date < ? AND pr.deletedAt IS NULL
      ORDER BY pr.date DESC
    ''', [
        dateString,
        DateTime(date.year, date.month, date.day + 1).toIso8601String()
      ]);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('查询生产记录出错: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDailySummary(DateTime date) async {
    final db = await instance.database;
    final startDate =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final endDate =
        DateTime(date.year, date.month, date.day + 1).toIso8601String();
    return await db.rawQuery('''
      SELECT 
        p.id, 
        p.productType, 
        p.productCode, 
        SUM(pr.quantity) as totalQuantity,
        COUNT(pr.id) as recordCount
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date >= ? AND pr.date < ? AND p.isActive = 1 AND pr.deletedAt IS NULL
      GROUP BY p.id
      ORDER BY p.productCode ASC
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummary(
      int year, int month) async {
    final db = await instance.database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.productType, 
        p.productCode, 
        SUM(pr.quantity) as totalQuantity,
        COUNT(pr.id) as recordCount
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date >= ? AND pr.date < ? AND p.isActive = 1 AND pr.deletedAt IS NULL
      GROUP BY p.id
      ORDER BY p.productCode ASC
    ''', [startDate, endDate]);
  }

  // 修复后的 getRecordsByDateRange 方法
  Future<List<ProductionRecord>> getRecordsByDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;

    // 将日期转换为 ISO8601 字符串格式进行比较
    final startDateString = startDate.toIso8601String();
    final endDateString = endDate.toIso8601String();

    try {
      final result = await db.rawQuery('''
        SELECT 
          $_recordSelectColumns
        FROM production_records pr
        JOIN products p ON pr.productId = p.id
        WHERE pr.date >= ? AND pr.date <= ? AND p.isActive = 1 AND pr.deletedAt IS NULL
        ORDER BY p.productType ASC, pr.date DESC
      ''', [startDateString, endDateString]);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('查询日期范围生产记录出错: $e');
      return [];
    }
  }

  /// 获取一个月内某个产品类型的生产总数
  Future<int> getMonthlyProductionCountByType(
      String productType, int year, int month) async {
    final db = await instance.database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    final result = await db.rawQuery('''
    SELECT SUM(pr.quantity) as total
    FROM production_records pr
    JOIN products p ON pr.productId = p.id
    WHERE p.productType = ? 
      AND pr.date >= ? AND pr.date < ?
      AND p.isActive = 1
      AND pr.deletedAt IS NULL
  ''', [productType, startDate, endDate]);

    return result.first['total'] as int? ?? 0;
  }

  /// 获取一个月内某个产品类型的生产汇总数据（包括每个产品的明细）
  Future<List<Map<String, dynamic>>> getMonthlyProductionByType(
      String productType, int year, int month) async {
    final db = await instance.database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.productCode, 
      p.description,
      SUM(pr.quantity) as totalQuantity,
      COUNT(pr.id) as recordCount
    FROM production_records pr
    JOIN products p ON pr.productId = p.id
    WHERE p.productType = ? 
      AND pr.date >= ? AND pr.date < ?
      AND p.isActive = 1
      AND pr.deletedAt IS NULL
    GROUP BY p.id
    ORDER BY p.productCode ASC
  ''', [productType, startDate, endDate]);
  }

  // 获取今天的生产记录，按ProductType分组
  Future<List<ProductionRecord>> getTodayProductionRecords() async {
    final db = await instance.database;
    final today = DateTime.now();
    final dateString =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    try {
      final result = await db.rawQuery('''
      SELECT 
        $_recordSelectColumns
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date >= ? AND pr.date < ? AND p.isActive = 1 AND pr.deletedAt IS NULL
      ORDER BY p.productType ASC, pr.date DESC
    ''', [
        dateString,
        DateTime(today.year, today.month, today.day + 1).toIso8601String()
      ]);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('查询今天生产记录出错: $e');
      return [];
    }
  }

  // 获取指定日期的生产记录，按ProductType分组
  Future<List<ProductionRecord>> getProductionRecordsBySpecificDate(
      DateTime date) async {
    final db = await instance.database;
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    try {
      final result = await db.rawQuery('''
      SELECT 
        $_recordSelectColumns
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date >= ? AND pr.date < ? AND p.isActive = 1 AND pr.deletedAt IS NULL
      ORDER BY p.productType ASC, pr.date DESC
    ''', [
        dateString,
        DateTime(date.year, date.month, date.day + 1).toIso8601String()
      ]);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('查询指定日期生产记录出错: $e');
      return [];
    }
  }

  // 获取指定月份的所有生产记录，按ProductType分组
  Future<List<ProductionRecord>> getMonthlyProductionRecords(
      int year, int month) async {
    final db = await instance.database;
    try {
      final result = await db.rawQuery('''
      SELECT 
        $_recordSelectColumns
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date >= ? AND pr.date < ? AND p.isActive = 1 AND pr.deletedAt IS NULL
      ORDER BY p.productType ASC, pr.date DESC
    ''', [
        DateTime(year, month, 1).toIso8601String(),
        DateTime(year, month + 1, 1).toIso8601String(),
      ]);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('查询月度生产记录出错: $e');
      return [];
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  Future<Product> getOrCreateProduct(Product product) async {
    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'products',
        where: 'productCode = ? AND productType = ?',
        whereArgs: [product.productCode, productTypeDisplayNames[product.type]],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return Product.fromMap(existing.first);
      }
      final id = await txn.insert('products', product.toMap());
      return product.copy(id: id);
    });
  }

  Future<ProductionRecord> createProductionRecordWithProduct({
    required ProductType productType,
    required String productCode,
    required int quantity,
    required DateTime date,
    required bool isRework,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'products',
        where: 'productCode = ? AND productType = ?',
        whereArgs: [productCode, productTypeDisplayNames[productType]],
        limit: 1,
      );

      final Product product;
      if (existing.isNotEmpty) {
        product = Product.fromMap(existing.first);
      } else {
        final newProduct = Product(type: productType, productCode: productCode);
        final productId = await txn.insert('products', newProduct.toMap());
        product = newProduct.copy(id: productId);
      }

      final now = DateTime.now();
      final record = ProductionRecord(
        productId: product.id!,
        productType: productType,
        productCode: productCode,
        quantity: quantity,
        date: date,
        isRework: isRework,
        clientUuid: _createClientUuid(),
        syncStatus: SyncStatus.pending,
        retryCount: 0,
        updatedAt: now,
      );
      final id = await txn.insert('production_records', record.toMap());
      return record.copy(id: id);
    });
  }

  Future<List<ProductionRecord>> getRecordsNeedingSync({int limit = 50}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT $_recordSelectColumns
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.syncStatus IN (?, ?, ?)
      ORDER BY pr.updatedAt ASC
      LIMIT ?
    ''', [
      SyncStatus.pending.name,
      SyncStatus.failed.name,
      SyncStatus.deletedPending.name,
      limit,
    ]);
    return result.map(ProductionRecord.fromMap).toList();
  }

  Future<void> markRecordsSyncing(List<String> clientUuids) async {
    if (clientUuids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(clientUuids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE production_records SET syncStatus = ? WHERE clientUuid IN ($placeholders)',
      [SyncStatus.syncing.name, ...clientUuids],
    );
  }

  Future<void> markRecordSynced({
    required String clientUuid,
    required String? serverId,
  }) async {
    final db = await database;
    await db.update(
      'production_records',
      {
        'serverId': serverId,
        'syncStatus': SyncStatus.synced.name,
        'syncError': null,
        'lastSyncAt': DateTime.now().toIso8601String(),
      },
      where: 'clientUuid = ?',
      whereArgs: [clientUuid],
    );
  }

  Future<void> markRecordSyncFailed({
    required String clientUuid,
    required String error,
  }) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE production_records
      SET syncStatus = ?,
          syncError = ?,
          retryCount = COALESCE(retryCount, 0) + 1
      WHERE clientUuid = ?
    ''', [SyncStatus.failed.name, error, clientUuid]);
  }

  Future<void> markSyncingRecordsFailed(String error) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE production_records
      SET syncStatus = ?,
          syncError = ?,
          retryCount = COALESCE(retryCount, 0) + 1
      WHERE syncStatus = ?
    ''', [SyncStatus.failed.name, error, SyncStatus.syncing.name]);
  }
}
