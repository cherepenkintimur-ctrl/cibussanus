import 'package:postgres/postgres.dart';

import 'db_config.dart';

class DbService {
  DbService._();

  static final DbService instance = DbService._();

  Connection? _connection;

  bool get isConnected => _connection?.isOpen ?? false;

  Future<Connection> _ensureConnection() async {
    final existing = _connection;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final connection = await Connection.openFromUrl(DbConfig.connectionUrl);
    _connection = connection;
    return connection;
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    final connection = await _ensureConnection();
    await connection.execute('BEGIN');
    try {
      final result = await action();
      await connection.execute('COMMIT');
      return result;
    } catch (_) {
      await connection.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Result> execute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    final connection = await _ensureConnection();
    if (parameters == null || parameters.isEmpty) {
      return connection.execute(sql);
    }

    return connection.execute(
      Sql.named(sql),
      parameters: parameters,
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    final result = await execute(sql, parameters: parameters);
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>?> queryOne(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    final rows = await query(sql, parameters: parameters);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> close() async {
    final connection = _connection;
    if (connection == null) return 0;
    await connection.close();
    _connection = null;
    return 1;
  }
}
