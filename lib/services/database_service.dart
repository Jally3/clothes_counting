import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/production_record_model.dart';
import '../models/product_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('production_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    // const realType = 'REAL NOT NULL'; // 如果需要浮点数

    await db.execute('''
      CREATE TABLE products (
        id $idType,
        productType $textType,
        productCode $textType UNIQUE,
        style $textType
      )
      ''');

    await db.execute('''
      CREATE TABLE production_records (
        id $idType,
        productId INTEGER NOT NULL,
        date $textType,
        quantity $integerType,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
      ''');
  }

  // 产品相关的操作
  Future<Product> createProduct(Product product) async {
    final db = await instance.database;
    final id = await db.insert('products', product.toMap());
    return product.copy(id: id);
  }

  Future<Product?> getProductByCode(String productCode) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      columns: ['id', 'productType', 'productCode', 'style'],
      where: 'productCode = ?',
      whereArgs: [productCode],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products', orderBy: 'productCode ASC');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  // 生产记录相关的操作
  Future<ProductionRecord> createProductionRecord(ProductionRecord record) async {
    final db = await instance.database;
    final id = await db.insert('production_records', record.toMap());
    return record.copy(id: id);
  }

  Future<List<ProductionRecord>> getProductionRecordsByDate(DateTime date) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().substring(0, 10); // YYYY-MM-DD
    final result = await db.query(
      'production_records',
      where: 'date LIKE ?',
      whereArgs: ['$dateString%'], // 查询特定日期的数据
      orderBy: 'date DESC',
    );
    // 注意：这里需要确保 ProductionRecord.fromMap 能够正确处理从数据库读取的数据
    // 可能需要根据实际情况调整 Product 和 ProductionRecord 模型的 fromMap 方法
    return result.map((json) => ProductionRecord.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getDailySummary(DateTime date) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT p.productType, p.productCode, p.style, SUM(pr.quantity) as totalQuantity
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE pr.date LIKE ?
      GROUP BY p.id
      ORDER BY p.productCode ASC
    ''', ['$dateString%']);
    return result;
  }

  Future<List<Map<String, dynamic>>> getMonthlySummary(int year, int month) async {
    final db = await instance.database;
    // 格式化月份为两位数，例如 01, 02, ..., 12
    final monthString = month.toString().padLeft(2, '0');
    final result = await db.rawQuery('''
      SELECT p.productType, p.productCode, p.style, SUM(pr.quantity) as totalQuantity
      FROM production_records pr
      JOIN products p ON pr.productId = p.id
      WHERE strftime('%Y-%m', pr.date) = ?
      GROUP BY p.id
      ORDER BY p.productCode ASC
    ''', ['$year-$monthString']);
    return result;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}