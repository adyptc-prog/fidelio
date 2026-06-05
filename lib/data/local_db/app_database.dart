import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/services/local_database_service.dart';

class AppDatabase implements LocalDatabaseService, QueryExecutorUser {
  AppDatabase([QueryExecutor? executor])
    : _executor = executor ?? _openConnection();

  AppDatabase.memory() : _executor = NativeDatabase.memory();

  final QueryExecutor _executor;
  bool _opened = false;

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  Future<void> open() async {
    if (_opened) {
      return;
    }
    await _executor.ensureOpen(this);
    for (final statement in _schemaStatements) {
      await _executor.runCustom(statement);
    }
    for (final migration in _columnMigrationStatements) {
      if (!await _columnExists(_executor, migration.table, migration.column)) {
        await _executor.runCustom(migration.statement);
      }
    }
    for (final statement in _postMigrationStatements) {
      await _executor.runCustom(statement);
    }
    for (final statement in _dataRepairStatements) {
      await _executor.runCustom(statement);
    }
    for (final statement in _indexStatements) {
      await _executor.runCustom(statement);
    }
    await _executor.runCustom('PRAGMA user_version = $schemaVersion');
    _opened = true;
  }

  @override
  Future<void> close() async {
    await _executor.close();
    _opened = false;
  }

  @override
  Future<void> runMigration() async {
    await open();
    await _executor.runCustom('PRAGMA user_version = $schemaVersion');
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    await open();
    await _executor.runCustom('BEGIN IMMEDIATE');
    try {
      final result = await action();
      await _executor.runCustom('COMMIT');
      return result;
    } catch (_) {
      await _executor.runCustom('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> select(
    String statement, [
    List<Object?> args = const [],
  ]) async {
    await open();
    return _executor.runSelect(statement, args);
  }

  Future<int> insert(String statement, [List<Object?> args = const []]) async {
    await open();
    return _executor.runInsert(statement, args);
  }

  Future<int> update(String statement, [List<Object?> args = const []]) async {
    await open();
    return _executor.runUpdate(statement, args);
  }

  Future<int> delete(String statement, [List<Object?> args = const []]) async {
    await open();
    return _executor.runDelete(statement, args);
  }

  Future<bool> _columnExists(
    QueryExecutor executor,
    String table,
    String column,
  ) async {
    final rows = await executor.runSelect(
      'PRAGMA table_info($table)',
      const [],
    );
    return rows.any((row) => row['name'] == column);
  }
}

class _ColumnMigrationStatement {
  const _ColumnMigrationStatement({
    required this.table,
    required this.column,
    required this.statement,
  });

  final String table;
  final String column;
  final String statement;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbFile = File(
      p.join(documentsDirectory.path, 'local_loyalty.sqlite'),
    );
    await _repairInvalidDatabase(dbFile);
    return NativeDatabase.createInBackground(dbFile);
  });
}

Future<void> _repairInvalidDatabase(File dbFile) async {
  if (!await dbFile.exists()) {
    return;
  }
  if (await _isSqliteDatabase(dbFile)) {
    return;
  }

  final safetyFile = File(
    p.join(dbFile.parent.path, 'local_loyalty.before_restore.sqlite'),
  );
  if (await _isSqliteDatabase(safetyFile)) {
    await _deleteWalFiles(dbFile);
    await safetyFile.copy(dbFile.path);
    return;
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  await _deleteWalFiles(dbFile);
  await dbFile.rename(
    p.join(dbFile.parent.path, 'local_loyalty.invalid_$timestamp.sqlite'),
  );
}

Future<bool> _isSqliteDatabase(File file) async {
  if (!await file.exists()) {
    return false;
  }
  if (await file.length() < _sqliteHeader.length) {
    return false;
  }

  final input = await file.open();
  try {
    final header = await input.read(_sqliteHeader.length);
    if (header.length != _sqliteHeader.length) {
      return false;
    }
    for (var index = 0; index < _sqliteHeader.length; index++) {
      if (header[index] != _sqliteHeader[index]) {
        return false;
      }
    }
    return true;
  } finally {
    await input.close();
  }
}

Future<void> _deleteWalFiles(File dbFile) async {
  for (final suffix in ['-wal', '-shm']) {
    final file = File('${dbFile.path}$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}

const _sqliteHeader = [
  0x53,
  0x51,
  0x4C,
  0x69,
  0x74,
  0x65,
  0x20,
  0x66,
  0x6F,
  0x72,
  0x6D,
  0x61,
  0x74,
  0x20,
  0x33,
  0x00,
];

const _schemaStatements = [
  '''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS business_profiles (
  business_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  activity_domain TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  card_accent_color INTEGER,
  activity_symbol TEXT,
  local_public_key TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS customer_records (
  customer_id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  display_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  phone TEXT,
  email TEXT,
  notes TEXT,
  linked_wallet_id TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS subscription_cards (
  card_id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  subscription_type TEXT NOT NULL DEFAULT 'custom',
  starts_at INTEGER,
  expires_at INTEGER,
  notes TEXT,
  valid_until INTEGER,
  remaining_uses INTEGER,
  linked_wallet_id TEXT,
  dynamic_challenge TEXT,
  challenge_timestamp INTEGER,
  challenge_signature TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS loyalty_cards (
  card_id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  current_stamps INTEGER NOT NULL,
  reward_threshold INTEGER NOT NULL,
  program_type TEXT NOT NULL DEFAULT 'stamps',
  points_per_scan INTEGER,
  challenge_window_days INTEGER,
  challenge_started_at INTEGER,
  valid_until INTEGER,
  linked_wallet_id TEXT,
  dynamic_challenge TEXT,
  challenge_timestamp INTEGER,
  challenge_signature TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS wallet_cards (
  wallet_card_id TEXT PRIMARY KEY,
  wallet_id TEXT NOT NULL,
  business_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  card_type TEXT NOT NULL,
  display_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  business_name TEXT,
  business_domain TEXT,
  business_symbol TEXT,
  business_accent_color INTEGER,
  entries_total INTEGER,
  entries_remaining INTEGER,
  scan_value INTEGER,
  valid_until INTEGER,
  dynamic_challenge TEXT,
  challenge_timestamp INTEGER,
  challenge_signature TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS check_in_events (
  event_id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  challenge_timestamp INTEGER NOT NULL,
  signature TEXT NOT NULL,
  customer_id TEXT,
  result TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS loyalty_transactions (
  transaction_id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  stamp_delta INTEGER NOT NULL,
  reward_issued INTEGER NOT NULL DEFAULT 0,
  note TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS license_info (
  license_id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  issued_at INTEGER NOT NULL,
  is_lifetime INTEGER NOT NULL,
  signature TEXT NOT NULL,
  valid_until INTEGER,
  source_path TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS backup_info (
  backup_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  path TEXT NOT NULL,
  checksum TEXT NOT NULL,
  business_id TEXT
)
''',
];

const _dataRepairStatements = [
  '''
DELETE FROM check_in_events
WHERE result = 'valid'
AND rowid NOT IN (
  SELECT MIN(rowid)
  FROM check_in_events
  WHERE result = 'valid'
  GROUP BY business_id, card_id, signature
)
''',
];

const _indexStatements = [
  '''
CREATE UNIQUE INDEX IF NOT EXISTS unique_valid_check_in_signature
ON check_in_events (business_id, card_id, signature)
WHERE result = 'valid'
''',
  '''
CREATE INDEX IF NOT EXISTS idx_subscription_cards_business_id
ON subscription_cards (business_id)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_subscription_cards_customer_id
ON subscription_cards (customer_id)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_business_id
ON loyalty_cards (business_id)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_customer_id
ON loyalty_cards (customer_id)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_customer_records_business_id
ON customer_records (business_id)
''',
];

const _columnMigrationStatements = [
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'activity_domain',
    statement: 'ALTER TABLE business_profiles ADD COLUMN activity_domain TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'phone',
    statement: 'ALTER TABLE business_profiles ADD COLUMN phone TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'email',
    statement: 'ALTER TABLE business_profiles ADD COLUMN email TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'address',
    statement: 'ALTER TABLE business_profiles ADD COLUMN address TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'card_accent_color',
    statement:
        'ALTER TABLE business_profiles ADD COLUMN card_accent_color INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'activity_symbol',
    statement: 'ALTER TABLE business_profiles ADD COLUMN activity_symbol TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'business_profiles',
    column: 'local_public_key',
    statement: 'ALTER TABLE business_profiles ADD COLUMN local_public_key TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'customer_records',
    column: 'updated_at',
    statement: 'ALTER TABLE customer_records ADD COLUMN updated_at INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'customer_records',
    column: 'status',
    statement:
        "ALTER TABLE customer_records ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
  ),
  _ColumnMigrationStatement(
    table: 'customer_records',
    column: 'phone',
    statement: 'ALTER TABLE customer_records ADD COLUMN phone TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'customer_records',
    column: 'email',
    statement: 'ALTER TABLE customer_records ADD COLUMN email TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'subscription_cards',
    column: 'subscription_type',
    statement:
        "ALTER TABLE subscription_cards ADD COLUMN subscription_type TEXT NOT NULL DEFAULT 'custom'",
  ),
  _ColumnMigrationStatement(
    table: 'subscription_cards',
    column: 'starts_at',
    statement: 'ALTER TABLE subscription_cards ADD COLUMN starts_at INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'subscription_cards',
    column: 'expires_at',
    statement: 'ALTER TABLE subscription_cards ADD COLUMN expires_at INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'subscription_cards',
    column: 'notes',
    statement: 'ALTER TABLE subscription_cards ADD COLUMN notes TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'subscription_cards',
    column: 'linked_wallet_id',
    statement:
        'ALTER TABLE subscription_cards ADD COLUMN linked_wallet_id TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'business_name',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN business_name TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'business_domain',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN business_domain TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'business_symbol',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN business_symbol TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'business_accent_color',
    statement:
        'ALTER TABLE wallet_cards ADD COLUMN business_accent_color INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'entries_total',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN entries_total INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'entries_remaining',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN entries_remaining INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'scan_value',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN scan_value INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'loyalty_cards',
    column: 'program_type',
    statement:
        "ALTER TABLE loyalty_cards ADD COLUMN program_type TEXT NOT NULL DEFAULT 'stamps'",
  ),
  _ColumnMigrationStatement(
    table: 'loyalty_cards',
    column: 'points_per_scan',
    statement: 'ALTER TABLE loyalty_cards ADD COLUMN points_per_scan INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'loyalty_cards',
    column: 'challenge_window_days',
    statement:
        'ALTER TABLE loyalty_cards ADD COLUMN challenge_window_days INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'loyalty_cards',
    column: 'challenge_started_at',
    statement:
        'ALTER TABLE loyalty_cards ADD COLUMN challenge_started_at INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'loyalty_cards',
    column: 'linked_wallet_id',
    statement: 'ALTER TABLE loyalty_cards ADD COLUMN linked_wallet_id TEXT',
  ),
];

const _postMigrationStatements = [
  '''
UPDATE customer_records
SET updated_at = created_at
WHERE updated_at IS NULL
''',
];
