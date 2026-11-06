
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static Database? _database;

  static const int _databaseVersion = 1;
  static const String _databaseName = 'albraihi_local.db';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول البيانات المخزنة محلياً
    await db.execute('''
      CREATE TABLE local_data (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول العمليات التي تنتظر المزامنة
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // جدول معلومات آخر مزامنة
    await db.execute('''
      CREATE TABLE sync_metadata (
        table_name TEXT PRIMARY KEY,
        last_sync TEXT
      )
    ''');

    // فهرس لتسريع الوصول إلى العمليات المعلقة
    await db.execute('''
      CREATE INDEX idx_pending_created
      ON pending_operations(created_at)
    ''');
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // ستضاف ترقيات قاعدة البيانات هنا مستقبلاً.
  }

  Future<int> saveData(Map<String, dynamic> data) async {
    final db = await database;

    return await db.insert(
      'local_data',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getData(String id) async {
    final db = await database;

    final result = await db.query(
      'local_data',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first;
  }

  Future<List<Map<String, dynamic>>> getAllData(
    String tableName,
  ) async {
    final db = await database;

    return await db.query(
      'local_data',
      where: 'table_name = ?',
      whereArgs: [tableName],
      orderBy: 'updated_at DESC',
    );
  }

  Future<int> deleteData(String id) async {
    final db = await database;

    return await db.delete(
      'local_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
