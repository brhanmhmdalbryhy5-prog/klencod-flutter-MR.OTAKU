
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local/local_database.dart';

class SyncManager {
  SyncManager._();

  static final SyncManager instance = SyncManager._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDatabase _database = LocalDatabase.instance;

  StreamSubscription<bool>? _connectionSubscription;

  bool _isSyncing = false;
  bool _isStarted = false;

  bool get isSyncing => _isSyncing;

  static const List<String> _cacheTables = [
    'news',
    'players',
    'latest',
    'important_news',
    'gallery',
    'posts',
    'post_comments',
    'post_likes',
    'stories',
    'polls',
    'poll_options',
    'poll_votes',
    'quiz_questions',
    'rating_anime',
    'rating_characters',
    'anime_ratings',
    'character_ratings',
    'favorites',
    'follows',
    'saved_posts',
    'user_rewards',
    'news_likes',
    'notifications',
  ];

  static const Map<String, List<String>> _insertUniqueKeys = {
    'favorites': [
      'account_id',
      'item_type',
      'item_id',
    ],
    'follows': [
      'follower_id',
      'following_id',
    ],
    'post_likes': [
      'post_id',
      'account_id',
    ],
    'saved_posts': [
      'post_id',
      'account_id',
    ],
    'poll_votes': [
      'poll_id',
      'client_id',
    ],
    'anime_ratings': [
      'anime_id',
      'account_id',
    ],
    'character_ratings': [
      'character_id',
      'account_id',
    ],
    'comment_likes': [
      'comment_id',
      'comment_type',
      'account_id',
    ],
    'user_rewards': [
      'account_id',
      'reward_name',
    ],
  };

  /// بدء مراقبة الاتصال.
  Future<void> start({
    required Stream<bool> connectionStream,
  }) async {
    if (_isStarted) return;

    _isStarted = true;

    await _connectionSubscription?.cancel();

    _connectionSubscription = connectionStream.listen(
      (connected) {
        if (connected) {
          syncAll();
        }
      },
      onError: (error) {
        debugPrint('Sync connection error: $error');
      },
    );
  }

  /// مزامنة البيانات والعمليات المعلقة.
  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      await syncPendingOperations();
      await syncTables();
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// تحميل البيانات من Supabase وحفظها محلياً.
  Future<void> syncTables() async {
    for (final table in _cacheTables) {
      try {
        final result = await _supabase
            .from(table)
            .select();

        final rows = List<Map<String, dynamic>>.from(result);

        for (final row in rows) {
          final id = _getRecordId(table, row);

          if (id == null || id.isEmpty) continue;

          await _database.saveData(
            id: id,
            tableName: table,
            data: row,
          );
        }

        await _database.updateLastSync(table);

        debugPrint(
          'Cached $table: ${rows.length} records',
        );
      } catch (e) {
        debugPrint('Cache error [$table]: $e');
      }
    }
  }

  /// تحديد المفتاح المحلي للسجل.
  String? _getRecordId(
    String table,
    Map<String, dynamic> row,
  ) {
    final id = row['id'];

    if (id == null) return null;

    if (table == 'news') {
      return '${id}_${row['title'] ?? ''}';
    }

    return id.toString();
  }

  /// قراءة بيانات جدول من SQLite.
  Future<List<Map<String, dynamic>>> getLocalData(
    String table,
  ) {
    return _database.getAllData(table);
  }

  /// قراءة سجل واحد من SQLite.
  Future<Map<String, dynamic>?> getLocalRecord({
    required String table,
    required String id,
  }) {
    return _database.getData(
      tableName: table,
      id: id,
    );
  }

  /// إضافة عملية إدخال آمنة إلى قائمة الانتظار.
  Future<bool> enqueueInsert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final uniqueColumns = _insertUniqueKeys[table];

    if (uniqueColumns == null) {
      debugPrint(
        'Unsafe offline insert rejected: $table',
      );
      return false;
    }

    for (final column in uniqueColumns) {
      if (!data.containsKey(column) || data[column] == null) {
        debugPrint(
          'Missing unique field $column in $table',
        );
        return false;
      }
    }

    final recordId = uniqueColumns
        .map((column) => '${data[column]}')
        .join('|');

    await _database.addPendingOperation(
      tableName: table,
      recordId: recordId,
      operation: 'insert',
      data: data,
    );

    return true;
  }

  /// إضافة عملية تعديل إلى قائمة الانتظار.
  Future<void> enqueueUpdate({
    required String table,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    await _database.addPendingOperation(
      tableName: table,
      recordId: recordId,
      operation: 'update',
      data: data,
    );
  }

  /// إضافة عملية حذف إلى قائمة الانتظار.
  Future<void> enqueueDelete({
    required String table,
    required String recordId,
  }) async {
    await _database.addPendingOperation(
      tableName: table,
      recordId: recordId,
      operation: 'delete',
    );
  }

  /// تنفيذ العمليات المعلقة بالترتيب.
  Future<void> syncPendingOperations() async {
    final operations =
        await _database.getPendingOperations();

    for (final operation in operations) {
      final operationId = operation['id'] as int;
      final table = operation['table_name'] as String;
      final recordId = operation['record_id'] as String;
      final action = operation['operation'] as String;

      try {
        final data = operation['data'] == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(
                operation['data'] as Map,
              );

        switch (action) {
          case 'insert':
            await _pushInsert(table, data);
            break;

          case 'update':
            await _pushUpdate(table, recordId, data);
            break;

          case 'delete':
            await _pushDelete(table, recordId);
            break;

          default:
            throw Exception(
              'Unknown operation: $action',
            );
        }

        await _database.removePendingOperation(
          operationId,
        );

        debugPrint(
          'Synced $action on $table',
        );
      } catch (e) {
        await _database.incrementRetryCount(
          operationId,
        );

        debugPrint(
          'Pending operation failed [$table]: $e',
        );
      }
    }
  }

  Future<void> _pushInsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final uniqueColumns = _insertUniqueKeys[table];

    if (uniqueColumns == null) {
      throw Exception(
        'No safe unique key for $table',
      );
    }

    await _supabase.from(table).upsert(
      data,
      onConflict: uniqueColumns.join(','),
    );
  }

  Future<void> _pushUpdate(
    String table,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (!_cacheTables.contains(table)) {
      throw Exception(
        'Table not allowed: $table',
      );
    }

    await _supabase
        .from(table)
        .update(data)
        .eq('id', recordId);
  }

  Future<void> _pushDelete(
    String table,
    String recordId,
  ) async {
    if (!_cacheTables.contains(table)) {
      throw Exception(
        'Table not allowed: $table',
      );
    }

    await _supabase
        .from(table)
        .delete()
        .eq('id', recordId);
  }

  /// إيقاف مراقبة الاتصال.
  Future<void> dispose() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _isStarted = false;
  }
}
