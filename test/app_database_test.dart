import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/data/local_db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await db.open();
  });

  tearDown(() => db.close());

  group('AppDatabase schema', () {
    test('all required tables exist after open', () async {
      final rows = await db.select(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = rows.map((r) => r['name'] as String).toSet();

      expect(names, containsAll([
        'app_settings',
        'backup_info',
        'business_profiles',
        'check_in_events',
        'customer_records',
        'license_info',
        'loyalty_cards',
        'loyalty_transactions',
        'subscription_cards',
        'wallet_cards',
      ]));
    });

    test('open is idempotent — calling twice does not error', () async {
      await db.open();
      final rows = await db.select(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(rows, isNotEmpty);
    });
  });

  group('AppDatabase transactions', () {
    test('successful transaction commits data', () async {
      await db.transaction(() async {
        await db.insert(
          "INSERT INTO app_settings (key, value) VALUES ('tx_key', 'tx_val')",
        );
      });

      final rows = await db.select(
        "SELECT value FROM app_settings WHERE key = 'tx_key'",
      );
      expect(rows.length, 1);
      expect(rows.first['value'], 'tx_val');
    });

    test('failed transaction rolls back — data is not persisted', () async {
      await expectLater(
        db.transaction(() async {
          await db.insert(
            "INSERT INTO app_settings (key, value) VALUES ('rollback_key', 'v')",
          );
          throw Exception('intentional failure');
        }),
        throwsException,
      );

      final rows = await db.select(
        "SELECT * FROM app_settings WHERE key = 'rollback_key'",
      );
      expect(rows, isEmpty);
    });

    test('nested independent writes outside a transaction are each committed', () async {
      await db.insert(
        "INSERT INTO app_settings (key, value) VALUES ('k1', 'v1')",
      );
      await db.insert(
        "INSERT OR REPLACE INTO app_settings (key, value) VALUES ('k1', 'v2')",
      );

      final rows = await db.select(
        "SELECT value FROM app_settings WHERE key = 'k1'",
      );
      expect(rows.single['value'], 'v2');
    });
  });

  group('AppDatabase check-in anti-replay index', () {
    final now = DateTime.utc(2026, 5, 13).millisecondsSinceEpoch;

    test('first valid check-in is saved', () async {
      await db.insert('''
        INSERT INTO check_in_events
        (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
        VALUES ('ev-1', 'biz-1', 'card-1', ?, ?, 'sig-abc', 'valid')
      ''', [now, now]);

      final rows = await db.select('''
        SELECT 1 FROM check_in_events
        WHERE business_id = 'biz-1' AND card_id = 'card-1'
          AND signature = 'sig-abc' AND result = 'valid'
        LIMIT 1
      ''');
      expect(rows, hasLength(1));
    });

    test('second valid check-in with same signature is rejected by unique index', () async {
      await db.insert('''
        INSERT INTO check_in_events
        (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
        VALUES ('ev-1', 'biz-1', 'card-1', ?, ?, 'sig-replay', 'valid')
      ''', [now, now]);

      await expectLater(
        db.insert('''
          INSERT INTO check_in_events
          (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
          VALUES ('ev-2', 'biz-1', 'card-1', ?, ?, 'sig-replay', 'valid')
        ''', [now, now]),
        throwsA(anything),
      );
    });

    test('invalid check-ins with same signature are not constrained by index', () async {
      await db.insert('''
        INSERT INTO check_in_events
        (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
        VALUES ('ev-1', 'biz-1', 'card-1', ?, ?, 'sig-abc', 'invalid QR')
      ''', [now, now]);
      await db.insert('''
        INSERT INTO check_in_events
        (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
        VALUES ('ev-2', 'biz-1', 'card-1', ?, ?, 'sig-abc', 'invalid QR')
      ''', [now, now]);

      final rows = await db.select('''
        SELECT COUNT(*) as cnt FROM check_in_events
        WHERE signature = 'sig-abc'
      ''');
      expect(rows.first['cnt'], 2);
    });

    test('valid check-in for different card with same signature is allowed', () async {
      await db.insert('''
        INSERT INTO check_in_events
        (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
        VALUES ('ev-1', 'biz-1', 'card-1', ?, ?, 'sig-shared', 'valid')
      ''', [now, now]);
      await db.insert('''
        INSERT INTO check_in_events
        (event_id, business_id, card_id, occurred_at, challenge_timestamp, signature, result)
        VALUES ('ev-2', 'biz-1', 'card-2', ?, ?, 'sig-shared', 'valid')
      ''', [now, now]);

      final rows = await db.select(
        "SELECT COUNT(*) as cnt FROM check_in_events WHERE result = 'valid'",
      );
      expect(rows.first['cnt'], 2);
    });
  });
}
