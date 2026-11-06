
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static Database? _database;

  static const int _databaseVersion = 1;
  static const String _databaseName = 'mr_otaku_local.db';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_data (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_metadata (
        table_name TEXT PRIMARY KEY,
        last_sync TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_pending_created
      ON pending_operations(created_at)
    ''');
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {}

  // حفظ البيانات محلياً
  Future<void> saveData({
    required String id,
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;

    await db.insert(
      'local_data',
      {
        'id': '$tableName:$id',
        'table_name': tableName,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // جلب سجل واحد
  Future<Map<String, dynamic>?> getData({
    required String id,
    required String tableName,
  }) async {
    final db = await database;

    final result = await db.query(
      'local_data',
      where: 'id = ?',
      whereArgs: ['$tableName:$id'],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Map<String, dynamic>.from(
      jsonDecode(result.first['data'] as String),
    );
  }

  // جلب جميع بيانات جدول معين
  Future<List<Map<String, dynamic>>> getAllData(
    String tableName,
  ) async {
    final db = await database;

    final result = await db.query(
      'local_data',
      where: 'table_name = ?',
      whereArgs: [tableName],
      orderBy: 'updated_at DESC',
    );

    return result.map((row) {
      return Map<String, dynamic>.from(
        jsonDecode(row['data'] as String),
      );
    }).toList();
  }

  // حذف سجل
  Future<void> deleteData({
    required String id,
    required String tableName,
  }) async {
    final db = await database;

    await db.delete(
      'local_data',
      where: 'id = ?',
      whereArgs: ['$tableName:$id'],
    );
  }

  // إضافة عملية إلى قائمة انتظار المزامنة
  Future<int> addPendingOperation({
    required String tableName,
    required String recordId,
    required String operation,
    Map<String, dynamic>? data,
  }) async {
    final db = await database;

    return db.insert('pending_operations', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': data == null ? null : jsonEncode(data),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retry_count': 0,
    });
  }

  // جلب العمليات التي تنتظر المزامنة
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;

    final result = await db.query(
      'pending_operations',
      orderBy: 'created_at ASC',
    );

    return result.map((row) {
      final item = Map<String, dynamic>.from(row);

      if (item['data'] != null) {
        item['data'] = jsonDecode(item['data'] as String);
      }

      return item;
    }).toList();
  }

  // حذف عملية بعد نجاح مزامنتها
  Future<void> removePendingOperation(int id) async {
    final db = await database;

    await db.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // زيادة عدد محاولات المزامنة
  Future<void> incrementRetryCount(int id) async {
    final db = await database;

    await db.rawUpdate(
      '''
      UPDATE pending_operations
      SET retry_count = retry_count + 1
      WHERE id = ?
      ''',
      [id],
    );
  }

  // حفظ وقت آخر مزامنة
  Future<void> updateLastSync(String tableName) async {
    final db = await database;

    await db.insert(
      'sync_metadata',
      {
        'table_name': tableName,
        'last_sync': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // معرفة وقت آخر مزامنة
  Future<String?> getLastSync(String tableName) async {
    final db = await database;

    final result = await db.query(
      'sync_metadata',
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first['last_sync'] as String?;
  }

  // إغلاق قاعدة البيانات
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
