import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/production_record_model.dart';
import '../models/product_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  // 数据库版本号，用于未来升级
  static const int _databaseVersion = 2;

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
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 示例：从版本1升级到版本2的迁移逻辑
      await db.execute('ALTER TABLE products ADD COLUMN isActive INTEGER DEFAULT 1');
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
        productCode $textType UNIQUE,
        description $textNullable,
        price $realType DEFAULT 0.0,
        isActive $boolType DEFAULT 1,
        createdAt $textType DEFAULT (datetime('now','localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE production_records (
        id $idType,
        productId $integerType,
        date $textType,
        quantity $integerType,
        operatorId INTEGER,
        notes $textNullable,
        recordedAt $textType DEFAULT (datetime('now','localtime')),
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    // 产品表索引
    await db.execute('CREATE INDEX idx_products_productCode ON products(productCode)');
    await db.execute('CREATE INDEX idx_products_isActive ON products(isActive)');

    // 生产记录表索引
    await db.execute('CREATE INDEX idx_production_records_productId ON production_records(productId)');
    await db.execute('CREATE INDEX idx_production_records_date ON production_records(date)');
    await db.execute('CREATE INDEX idx_production_records_productId_date ON production_records(productId, date)');
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

  Future<Product?> getProductByCode(String productCode) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      where: 'productCode = ?',
      whereArgs: [productCode],
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
  Future<ProductionRecord> createProductionRecord(ProductionRecord record) async {
    final db = await instance.database;
    final id = await db.insert('production_records', record.toMap());
    return record.copy(id: id);
  }

  Future<List<ProductionRecord>> getProductionRecordsByProduct(int productId, {DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;

    final where = StringBuffer('productId = ?');
    final whereArgs = <dynamic>[productId];

    if (startDate != null) {
      where.write(' AND date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.write(' AND date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.query(
      'production_records',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    return result.map(ProductionRecord.fromMap).toList();
  }

  Future<List<ProductionRecord>> getProductionRecordsByDate(DateTime date) async {
    final db = await instance.database;
    final dateString = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";

    try {
      final result = await db.rawQuery('''
      SELECT 
        pr.id,
        pr.productId,
        p.productType,
        p.productCode,
        pr.quantity,
        pr.date,
        pr.operatorId,
        pr.notes
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date LIKE ?
      ORDER BY pr.date DESC
    ''', ['$dateString%']);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      print('查询生产记录出错: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDailySummary(DateTime date) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().substring(0, 10);
    return await db.rawQuery('''
      SELECT 
        p.id, 
        p.productType, 
        p.productCode, 
        SUM(pr.quantity) as totalQuantity,
        COUNT(pr.id) as recordCount
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date LIKE ? AND p.isActive = 1
      GROUP BY p.id
      ORDER BY p.productCode ASC
    ''', ['$dateString%']);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummary(int year, int month) async {
    final db = await instance.database;
    final monthString = month.toString().padLeft(2, '0');
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.productType, 
        p.productCode, 
        SUM(pr.quantity) as totalQuantity,
        COUNT(pr.id) as recordCount
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE strftime('%Y-%m', pr.date) = ? AND p.isActive = 1
      GROUP BY p.id
      ORDER BY p.productCode ASC
    ''', ['$year-$monthString']);
  }
  // 修复后的 getRecordsByDateRange 方法
  Future<List<ProductionRecord>> getRecordsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    
    // 将日期转换为 ISO8601 字符串格式进行比较
    final startDateString = startDate.toIso8601String();
    final endDateString = endDate.toIso8601String();
    
    try {
      final result = await db.rawQuery('''
        SELECT 
          pr.id,
          pr.productId,
          p.productType,
          p.productCode,
          pr.quantity,
          pr.date,
          pr.operatorId,
          pr.notes
        FROM production_records pr
        JOIN products p ON pr.productId = p.id
        WHERE pr.date >= ? AND pr.date <= ? AND p.isActive = 1
        ORDER BY p.productType ASC, pr.date DESC
      ''', [startDateString, endDateString]);
  
      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      print('查询日期范围生产记录出错: $e');
      return [];
    }
  }

  /// 获取一个月内某个产品类型的生产总数
  Future<int> getMonthlyProductionCountByType(String productType, int year, int month) async {
    final db = await instance.database;
    final monthString = month.toString().padLeft(2, '0');

    final result = await db.rawQuery('''
    SELECT SUM(pr.quantity) as total
    FROM production_records pr
    JOIN products p ON pr.productId = p.id
    WHERE p.productType = ? 
      AND strftime('%Y-%m', pr.date) = ?
      AND p.isActive = 1
  ''', [productType, '$year-$monthString']);

    return result.first['total'] as int? ?? 0;
  }

  /// 获取一个月内某个产品类型的生产汇总数据（包括每个产品的明细）
  Future<List<Map<String, dynamic>>> getMonthlyProductionByType(String productType, int year, int month) async {
    final db = await instance.database;
    final monthString = month.toString().padLeft(2, '0');

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
      AND strftime('%Y-%m', pr.date) = ?
      AND p.isActive = 1
    GROUP BY p.id
    ORDER BY p.productCode ASC
  ''', [productType, '$year-$monthString']);
  }

  Future<int> deleteProductionRecord(int id) async {
    final db = await instance.database;
    return await db.delete(
      'production_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // 获取今天的生产记录，按ProductType分组
  Future<List<ProductionRecord>> getTodayProductionRecords() async {
    final db = await instance.database;
    final today = DateTime.now();
    final dateString = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
    
    try {
      final result = await db.rawQuery('''
      SELECT 
        pr.id,
        pr.productId,
        p.productType,
        p.productCode,
        pr.quantity,
        pr.date,
        pr.operatorId,
        pr.notes
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date LIKE ? AND p.isActive = 1
      ORDER BY p.productType ASC, pr.date DESC
    ''', ['$dateString%']);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      print('查询今天生产记录出错: $e');
      return [];
    }
  }
  // 获取指定日期的生产记录，按ProductType分组
  Future<List<ProductionRecord>> getProductionRecordsBySpecificDate(DateTime date) async {
    final db = await instance.database;
    final dateString = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    
    try {
      final result = await db.rawQuery('''
      SELECT 
        pr.id,
        pr.productId,
        p.productType,
        p.productCode,
        pr.quantity,
        pr.date,
        pr.operatorId,
        pr.notes
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date LIKE ? AND p.isActive = 1
      ORDER BY p.productType ASC, pr.date DESC
    ''', ['$dateString%']);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      print('查询指定日期生产记录出错: $e');
      return [];
    }
  }

  // 获取指定月份的所有生产记录，按ProductType分组
  Future<List<ProductionRecord>> getMonthlyProductionRecords(int year, int month) async {
    final db = await instance.database;
    final monthString = month.toString().padLeft(2, '0');
    
    try {
      final result = await db.rawQuery('''
      SELECT 
        pr.id,
        pr.productId,
        p.productType,
        p.productCode,
        pr.quantity,
        pr.date,
        pr.operatorId,
        pr.notes
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE strftime('%Y-%m', pr.date) = ? AND p.isActive = 1
      ORDER BY p.productType ASC, pr.date DESC
    ''', ['$year-$monthString']);

      return result.map((map) => ProductionRecord.fromMap(map)).toList();
    } catch (e) {
      print('查询月度生产记录出错: $e');
      return [];
    }
  }
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}



