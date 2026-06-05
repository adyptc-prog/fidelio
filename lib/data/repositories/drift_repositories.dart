import '../../domain/entities/entities.dart';
import '../../domain/value_objects/app_mode.dart';
import '../../domain/value_objects/card_status.dart';
import '../../domain/value_objects/customer_status.dart';
import '../../domain/value_objects/loyalty_program_type.dart';
import '../../domain/value_objects/subscription_type.dart';
import '../local_db/app_database.dart';
import 'repository_interfaces.dart';

class DriftAppSettingsRepository implements AppSettingsRepository {
  const DriftAppSettingsRepository(this._db);

  static const _selectedModeKey = 'selected_mode';
  static const _clientCardsViewModeKey = 'client_cards_view_mode';
  static const _businessClientsViewModeKey = 'business_clients_view_mode';
  static const _zoomModeKey = 'zoom_mode';
  static const _darkModeKey = 'dark_mode';
  static const _clientWalletIdKey = 'client_wallet_id';

  final AppDatabase _db;

  @override
  Future<AppSettings> loadSettings() async {
    final rows = await _db.select('SELECT key, value FROM app_settings');
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String?,
    };

    return AppSettings(
      selectedMode: _mode(values[_selectedModeKey]),
      clientCardsViewMode: _clientCardsViewMode(
        values[_clientCardsViewModeKey],
      ),
      businessClientsViewMode: _businessClientsViewMode(
        values[_businessClientsViewModeKey],
      ),
      zoomMode: _zoomMode(values[_zoomModeKey]),
      darkMode: values[_darkModeKey] == 'true',
    );
  }

  @override
  Future<void> saveSelectedMode(AppMode mode) async {
    await _saveSetting(_selectedModeKey, mode.name);
  }

  @override
  Future<String?> loadClientWalletId() async {
    final rows = await _db.select(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      [_clientWalletIdKey],
    );
    final value = rows.isEmpty ? null : rows.first['value'] as String?;
    return value == null || value.trim().isEmpty ? null : value;
  }

  @override
  Future<void> saveClientWalletId(String walletId) async {
    await _saveSetting(_clientWalletIdKey, walletId);
  }

  @override
  Future<void> clearSelectedMode() async {
    await _db.delete('DELETE FROM app_settings WHERE key = ?', [
      _selectedModeKey,
    ]);
  }

  @override
  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode) async {
    await _saveSetting(_clientCardsViewModeKey, mode.name);
  }

  @override
  Future<void> saveBusinessClientsViewMode(BusinessClientsViewMode mode) async {
    await _saveSetting(_businessClientsViewModeKey, mode.name);
  }

  @override
  Future<void> saveZoomMode(AppZoomMode mode) async {
    await _saveSetting(_zoomModeKey, mode.name);
  }

  @override
  Future<void> saveDarkMode(bool enabled) async {
    await _saveSetting(_darkModeKey, enabled.toString());
  }

  Future<void> _saveSetting(String key, String value) {
    return _db.insert(
      '''
INSERT OR REPLACE INTO app_settings (key, value)
VALUES (?, ?)
''',
      [key, value],
    );
  }
}

class DriftBusinessRepository implements BusinessRepository {
  const DriftBusinessRepository(this._db);

  final AppDatabase _db;

  @override
  Future<BusinessProfile?> getActiveBusiness() async {
    final rows = await _db.select(
      'SELECT * FROM business_profiles ORDER BY created_at ASC LIMIT 1',
    );
    return rows.isEmpty ? null : _businessFromRow(rows.first);
  }

  @override
  Future<BusinessProfile?> getBusinessProfile(String businessId) async {
    final rows = await _db.select(
      'SELECT * FROM business_profiles WHERE business_id = ? LIMIT 1',
      [businessId],
    );
    return rows.isEmpty ? null : _businessFromRow(rows.first);
  }

  @override
  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO business_profiles
(business_id, display_name, created_at, activity_domain,
 phone, email, address, card_accent_color, activity_symbol,
 local_public_key)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        profile.businessId,
        profile.displayName,
        _date(profile.createdAt),
        profile.activityDomain,
        profile.phone,
        profile.email,
        profile.address,
        profile.cardAccentColor,
        profile.activitySymbol,
        profile.localPublicKey,
      ],
    );
  }

  @override
  Future<void> deleteBusinessProfile(String businessId) async {
    await _db.delete('DELETE FROM business_profiles WHERE business_id = ?', [
      businessId,
    ]);
  }
}

class DriftCustomerRepository implements CustomerRepository {
  const DriftCustomerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<CustomerRecord>> listCustomers(String businessId) async {
    final rows = await _db.select(
      '''
SELECT * FROM customer_records
WHERE business_id = ?
ORDER BY updated_at DESC
''',
      [businessId],
    );
    return rows.map(_customerFromRow).toList();
  }

  @override
  Future<List<CustomerRecord>> searchCustomers(
    String businessId,
    String query,
  ) async {
    final normalizedQuery = '%${query.trim().toLowerCase()}%';
    final rows = await _db.select(
      '''
SELECT * FROM customer_records
WHERE business_id = ?
  AND (
    lower(display_name) LIKE ?
    OR lower(coalesce(phone, '')) LIKE ?
    OR lower(coalesce(email, '')) LIKE ?
  )
ORDER BY
  CASE WHEN lower(coalesce(phone, '')) LIKE ? THEN 0 ELSE 1 END,
  updated_at DESC
''',
      [
        businessId,
        normalizedQuery,
        normalizedQuery,
        normalizedQuery,
        normalizedQuery,
      ],
    );
    return rows.map(_customerFromRow).toList();
  }

  @override
  Future<CustomerRecord?> getCustomer(String customerId) async {
    final rows = await _db.select(
      'SELECT * FROM customer_records WHERE customer_id = ? LIMIT 1',
      [customerId],
    );
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  @override
  Future<void> saveCustomer(CustomerRecord customer) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO customer_records
(customer_id, business_id, created_at, updated_at, display_name, status, phone,
 email, notes, linked_wallet_id)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        customer.customerId,
        customer.businessId,
        _date(customer.createdAt),
        _date(customer.updatedAt),
        customer.displayName,
        customer.status.name,
        customer.phone,
        customer.email,
        customer.notes,
        customer.linkedWalletId,
      ],
    );
  }

  @override
  Future<void> archiveCustomer(String customerId) async {
    await _db.update(
      '''
UPDATE customer_records
SET status = ?, updated_at = ?
WHERE customer_id = ?
''',
      [CustomerStatus.inactive.name, _date(DateTime.now()), customerId],
    );
  }

  @override
  Future<void> deleteCustomer(String customerId) async {
    await _db.delete('DELETE FROM customer_records WHERE customer_id = ?', [
      customerId,
    ]);
  }
}

class DriftCardRepository implements CardRepository {
  const DriftCardRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<SubscriptionCard>> listSubscriptionCards(
    String businessId,
  ) async {
    final rows = await _db.select(
      '''
SELECT * FROM subscription_cards
WHERE business_id = ?
ORDER BY created_at ASC
''',
      [businessId],
    );
    return rows.map(_subscriptionFromRow).toList();
  }

  @override
  Future<List<SubscriptionCard>> listSubscriptionCardsForCustomer(
    String customerId,
  ) async {
    final rows = await _db.select(
      '''
SELECT * FROM subscription_cards
WHERE customer_id = ?
ORDER BY created_at DESC
''',
      [customerId],
    );
    return rows.map(_subscriptionFromRow).toList();
  }

  @override
  Future<SubscriptionCard?> getSubscriptionCard(String cardId) async {
    final rows = await _db.select(
      'SELECT * FROM subscription_cards WHERE card_id = ? LIMIT 1',
      [cardId],
    );
    return rows.isEmpty ? null : _subscriptionFromRow(rows.first);
  }

  @override
  Future<List<LoyaltyCard>> listLoyaltyCards(String businessId) async {
    final rows = await _db.select(
      '''
SELECT * FROM loyalty_cards
WHERE business_id = ?
ORDER BY created_at ASC
''',
      [businessId],
    );
    return rows.map(_loyaltyFromRow).toList();
  }

  @override
  Future<List<LoyaltyCard>> listLoyaltyCardsForCustomer(
    String customerId,
  ) async {
    final rows = await _db.select(
      '''
SELECT * FROM loyalty_cards
WHERE customer_id = ?
ORDER BY created_at DESC
''',
      [customerId],
    );
    return rows.map(_loyaltyFromRow).toList();
  }

  @override
  Future<LoyaltyCard?> getLoyaltyCard(String cardId) async {
    final rows = await _db.select(
      'SELECT * FROM loyalty_cards WHERE card_id = ? LIMIT 1',
      [cardId],
    );
    return rows.isEmpty ? null : _loyaltyFromRow(rows.first);
  }

  @override
  Future<void> saveSubscriptionCard(SubscriptionCard card) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO subscription_cards
(card_id, business_id, customer_id, name, created_at, status,
 subscription_type, starts_at, expires_at, notes, valid_until, remaining_uses,
 linked_wallet_id, dynamic_challenge, challenge_timestamp, challenge_signature)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        card.cardId,
        card.businessId,
        card.customerId,
        card.name,
        _date(card.createdAt),
        card.status.name,
        card.subscriptionType.name,
        _nullableDate(card.startsAt),
        _nullableDate(card.expiresAt),
        card.notes,
        _nullableDate(card.validUntil),
        card.remainingUses,
        card.linkedWalletId,
        card.dynamicChallenge,
        _nullableDate(card.challengeTimestamp),
        card.challengeSignature,
      ],
    );
  }

  @override
  Future<void> saveLoyaltyCard(LoyaltyCard card) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO loyalty_cards
(card_id, business_id, customer_id, name, created_at, status, current_stamps,
 reward_threshold, program_type, points_per_scan, challenge_window_days,
 challenge_started_at, valid_until, linked_wallet_id, dynamic_challenge,
 challenge_timestamp, challenge_signature)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        card.cardId,
        card.businessId,
        card.customerId,
        card.name,
        _date(card.createdAt),
        card.status.name,
        card.currentStamps,
        card.rewardThreshold,
        card.programType.name,
        card.pointsPerScan,
        card.challengeWindowDays,
        _nullableDate(card.challengeStartedAt),
        _nullableDate(card.validUntil),
        card.linkedWalletId,
        card.dynamicChallenge,
        _nullableDate(card.challengeTimestamp),
        card.challengeSignature,
      ],
    );
  }

  @override
  Future<void> deleteSubscriptionCard(String cardId) async {
    await _db.delete('DELETE FROM subscription_cards WHERE card_id = ?', [
      cardId,
    ]);
  }

  @override
  Future<void> deleteLoyaltyCard(String cardId) async {
    await _db.delete('DELETE FROM loyalty_cards WHERE card_id = ?', [cardId]);
  }
}

class DriftWalletRepository implements WalletRepository {
  const DriftWalletRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<WalletCard>> listWalletCards(String walletId) async {
    final rows = await _db.select(
      '''
SELECT * FROM wallet_cards
WHERE wallet_id = ?
ORDER BY created_at ASC
''',
      [walletId],
    );
    return rows.map(_walletFromRow).toList();
  }

  @override
  Future<WalletCard?> getWalletCard(String walletCardId) async {
    final rows = await _db.select(
      'SELECT * FROM wallet_cards WHERE wallet_card_id = ? LIMIT 1',
      [walletCardId],
    );
    return rows.isEmpty ? null : _walletFromRow(rows.first);
  }

  @override
  Future<WalletCard?> getWalletCardByCardId({
    required String walletId,
    required String cardId,
  }) async {
    final rows = await _db.select(
      '''
SELECT * FROM wallet_cards
WHERE wallet_id = ? AND card_id = ?
LIMIT 1
''',
      [walletId, cardId],
    );
    return rows.isEmpty ? null : _walletFromRow(rows.first);
  }

  @override
  Future<void> saveWalletCard(WalletCard card) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO wallet_cards
(wallet_card_id, wallet_id, business_id, card_id, card_type, display_name,
 created_at, status, business_name, business_domain, business_symbol,
 business_accent_color, entries_total, entries_remaining, valid_until,
 scan_value, dynamic_challenge,
 challenge_timestamp, challenge_signature)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        card.walletCardId,
        card.walletId,
        card.businessId,
        card.cardId,
        card.cardType,
        card.displayName,
        _date(card.createdAt),
        card.status.name,
        card.businessName,
        card.businessDomain,
        card.businessSymbol,
        card.businessAccentColor,
        card.entriesTotal,
        card.entriesRemaining,
        _nullableDate(card.validUntil),
        card.scanValue,
        card.dynamicChallenge,
        _nullableDate(card.challengeTimestamp),
        card.challengeSignature,
      ],
    );
  }

  @override
  Future<void> deleteWalletCard(String walletCardId) async {
    await _db.delete('DELETE FROM wallet_cards WHERE wallet_card_id = ?', [
      walletCardId,
    ]);
  }
}

class DriftCheckInRepository implements CheckInRepository {
  const DriftCheckInRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<CheckInEvent>> listCheckIns(String businessId) async {
    final rows = await _db.select(
      '''
SELECT * FROM check_in_events
WHERE business_id = ?
ORDER BY occurred_at ASC
''',
      [businessId],
    );
    return rows.map(_checkInFromRow).toList();
  }

  @override
  Future<CheckInEvent?> getCheckIn(String eventId) async {
    final rows = await _db.select(
      'SELECT * FROM check_in_events WHERE event_id = ? LIMIT 1',
      [eventId],
    );
    return rows.isEmpty ? null : _checkInFromRow(rows.first);
  }

  @override
  Future<bool> hasValidCheckInForSignature({
    required String businessId,
    required String cardId,
    required String signature,
  }) async {
    final rows = await _db.select(
      '''
SELECT 1 FROM check_in_events
WHERE business_id = ?
  AND card_id = ?
  AND signature = ?
  AND result = 'valid'
LIMIT 1
''',
      [businessId, cardId, signature],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> saveCheckIn(CheckInEvent event) async {
    await _db.insert(
      '''
INSERT INTO check_in_events
(event_id, business_id, card_id, occurred_at, challenge_timestamp, signature,
 customer_id, result)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(event_id) DO UPDATE SET
  business_id = excluded.business_id,
  card_id = excluded.card_id,
  occurred_at = excluded.occurred_at,
  challenge_timestamp = excluded.challenge_timestamp,
  signature = excluded.signature,
  customer_id = excluded.customer_id,
  result = excluded.result
''',
      [
        event.eventId,
        event.businessId,
        event.cardId,
        _date(event.occurredAt),
        _date(event.challengeTimestamp),
        event.signature,
        event.customerId,
        event.result,
      ],
    );
  }

  @override
  Future<void> deleteCheckIn(String eventId) async {
    await _db.delete('DELETE FROM check_in_events WHERE event_id = ?', [
      eventId,
    ]);
  }
}

class DriftLoyaltyTransactionRepository
    implements LoyaltyTransactionRepository {
  const DriftLoyaltyTransactionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<LoyaltyTransaction>> listTransactions(String cardId) async {
    final rows = await _db.select(
      '''
SELECT * FROM loyalty_transactions
WHERE card_id = ?
ORDER BY created_at ASC
''',
      [cardId],
    );
    return rows.map(_transactionFromRow).toList();
  }

  @override
  Future<LoyaltyTransaction?> getTransaction(String transactionId) async {
    final rows = await _db.select(
      'SELECT * FROM loyalty_transactions WHERE transaction_id = ? LIMIT 1',
      [transactionId],
    );
    return rows.isEmpty ? null : _transactionFromRow(rows.first);
  }

  @override
  Future<void> saveTransaction(LoyaltyTransaction transaction) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO loyalty_transactions
(transaction_id, business_id, card_id, created_at, stamp_delta, reward_issued,
 note)
VALUES (?, ?, ?, ?, ?, ?, ?)
''',
      [
        transaction.transactionId,
        transaction.businessId,
        transaction.cardId,
        _date(transaction.createdAt),
        transaction.stampDelta,
        _bool(transaction.rewardIssued),
        transaction.note,
      ],
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    await _db.delete(
      'DELETE FROM loyalty_transactions WHERE transaction_id = ?',
      [transactionId],
    );
  }
}

class DriftLicenseRepository implements LicenseRepository {
  const DriftLicenseRepository(this._db);

  final AppDatabase _db;

  @override
  Future<LicenseInfo?> getLicense(String licenseId) async {
    final rows = await _db.select(
      'SELECT * FROM license_info WHERE license_id = ? LIMIT 1',
      [licenseId],
    );
    return rows.isEmpty ? null : _licenseFromRow(rows.first);
  }

  @override
  Future<List<LicenseInfo>> listLicenses(String businessId) async {
    final rows = await _db.select(
      '''
SELECT * FROM license_info
WHERE business_id = ?
ORDER BY issued_at ASC
''',
      [businessId],
    );
    return rows.map(_licenseFromRow).toList();
  }

  @override
  Future<void> saveLicense(LicenseInfo license) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO license_info
(license_id, business_id, issued_at, is_lifetime, signature, valid_until,
 source_path)
VALUES (?, ?, ?, ?, ?, ?, ?)
''',
      [
        license.licenseId,
        license.businessId,
        _date(license.issuedAt),
        _bool(license.isLifetime),
        license.signature,
        _nullableDate(license.validUntil),
        license.sourcePath,
      ],
    );
  }

  @override
  Future<void> deleteLicense(String licenseId) async {
    await _db.delete('DELETE FROM license_info WHERE license_id = ?', [
      licenseId,
    ]);
  }
}

class DriftBackupRepository implements BackupRepository {
  const DriftBackupRepository(this._db);

  final AppDatabase _db;

  @override
  Future<BackupInfo?> getBackup(String backupId) async {
    final rows = await _db.select(
      'SELECT * FROM backup_info WHERE backup_id = ? LIMIT 1',
      [backupId],
    );
    return rows.isEmpty ? null : _backupFromRow(rows.first);
  }

  @override
  Future<List<BackupInfo>> listBackups(String? businessId) async {
    final rows = businessId == null
        ? await _db.select('SELECT * FROM backup_info ORDER BY created_at ASC')
        : await _db.select(
            '''
SELECT * FROM backup_info
WHERE business_id = ?
ORDER BY created_at ASC
''',
            [businessId],
          );
    return rows.map(_backupFromRow).toList();
  }

  @override
  Future<void> saveBackup(BackupInfo backup) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO backup_info
(backup_id, created_at, path, checksum, business_id)
VALUES (?, ?, ?, ?, ?)
''',
      [
        backup.backupId,
        _date(backup.createdAt),
        backup.path,
        backup.checksum,
        backup.businessId,
      ],
    );
  }

  @override
  Future<void> deleteBackup(String backupId) async {
    await _db.delete('DELETE FROM backup_info WHERE backup_id = ?', [backupId]);
  }
}

BusinessProfile _businessFromRow(Map<String, Object?> row) {
  return BusinessProfile(
    businessId: row['business_id']! as String,
    displayName: row['display_name']! as String,
    createdAt: _readDate(row['created_at']),
    activityDomain: row['activity_domain'] as String?,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    address: row['address'] as String?,
    cardAccentColor: row['card_accent_color'] as int?,
    activitySymbol: row['activity_symbol'] as String?,
    localPublicKey: row['local_public_key'] as String?,
  );
}

CustomerRecord _customerFromRow(Map<String, Object?> row) {
  return CustomerRecord(
    customerId: row['customer_id']! as String,
    businessId: row['business_id']! as String,
    displayName: row['display_name']! as String,
    createdAt: _readDate(row['created_at']),
    updatedAt: _readDate(row['updated_at'] ?? row['created_at']),
    status: _customerStatus(row['status']),
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    notes: row['notes'] as String?,
    linkedWalletId: row['linked_wallet_id'] as String?,
  );
}

SubscriptionCard _subscriptionFromRow(Map<String, Object?> row) {
  return SubscriptionCard(
    businessId: row['business_id']! as String,
    cardId: row['card_id']! as String,
    customerId: row['customer_id']! as String,
    name: row['name']! as String,
    createdAt: _readDate(row['created_at']),
    status: _status(row['status']),
    subscriptionType: _subscriptionType(row['subscription_type']),
    startsAt: _readNullableDate(row['starts_at']),
    expiresAt: _readNullableDate(row['expires_at']),
    notes: row['notes'] as String?,
    validUntil: _readNullableDate(row['valid_until']),
    remainingUses: row['remaining_uses'] as int?,
    linkedWalletId: row['linked_wallet_id'] as String?,
    dynamicChallenge: row['dynamic_challenge'] as String?,
    challengeTimestamp: _readNullableDate(row['challenge_timestamp']),
    challengeSignature: row['challenge_signature'] as String?,
  );
}

LoyaltyCard _loyaltyFromRow(Map<String, Object?> row) {
  return LoyaltyCard(
    businessId: row['business_id']! as String,
    cardId: row['card_id']! as String,
    customerId: row['customer_id']! as String,
    name: row['name']! as String,
    createdAt: _readDate(row['created_at']),
    status: _status(row['status']),
    currentStamps: row['current_stamps']! as int,
    rewardThreshold: row['reward_threshold']! as int,
    programType: _loyaltyProgramType(row['program_type']),
    pointsPerScan: row['points_per_scan'] as int?,
    challengeWindowDays: row['challenge_window_days'] as int?,
    challengeStartedAt: _readNullableDate(row['challenge_started_at']),
    validUntil: _readNullableDate(row['valid_until']),
    linkedWalletId: row['linked_wallet_id'] as String?,
    dynamicChallenge: row['dynamic_challenge'] as String?,
    challengeTimestamp: _readNullableDate(row['challenge_timestamp']),
    challengeSignature: row['challenge_signature'] as String?,
  );
}

WalletCard _walletFromRow(Map<String, Object?> row) {
  return WalletCard(
    walletCardId: row['wallet_card_id']! as String,
    walletId: row['wallet_id']! as String,
    businessId: row['business_id']! as String,
    cardId: row['card_id']! as String,
    cardType: row['card_type']! as String,
    displayName: row['display_name']! as String,
    createdAt: _readDate(row['created_at']),
    status: _status(row['status']),
    businessName: row['business_name'] as String?,
    businessDomain: row['business_domain'] as String?,
    businessSymbol: row['business_symbol'] as String?,
    businessAccentColor: row['business_accent_color'] as int?,
    entriesTotal: row['entries_total'] as int?,
    entriesRemaining: row['entries_remaining'] as int?,
    scanValue: row['scan_value'] as int?,
    validUntil: _readNullableDate(row['valid_until']),
    dynamicChallenge: row['dynamic_challenge'] as String?,
    challengeTimestamp: _readNullableDate(row['challenge_timestamp']),
    challengeSignature: row['challenge_signature'] as String?,
  );
}

CheckInEvent _checkInFromRow(Map<String, Object?> row) {
  return CheckInEvent(
    eventId: row['event_id']! as String,
    businessId: row['business_id']! as String,
    cardId: row['card_id']! as String,
    occurredAt: _readDate(row['occurred_at']),
    challengeTimestamp: _readDate(row['challenge_timestamp']),
    signature: row['signature']! as String,
    customerId: row['customer_id'] as String?,
    result: row['result'] as String?,
  );
}

LoyaltyTransaction _transactionFromRow(Map<String, Object?> row) {
  return LoyaltyTransaction(
    transactionId: row['transaction_id']! as String,
    businessId: row['business_id']! as String,
    cardId: row['card_id']! as String,
    createdAt: _readDate(row['created_at']),
    stampDelta: row['stamp_delta']! as int,
    rewardIssued: _readBool(row['reward_issued']),
    note: row['note'] as String?,
  );
}

LicenseInfo _licenseFromRow(Map<String, Object?> row) {
  return LicenseInfo(
    licenseId: row['license_id']! as String,
    businessId: row['business_id']! as String,
    issuedAt: _readDate(row['issued_at']),
    isLifetime: _readBool(row['is_lifetime']),
    signature: row['signature']! as String,
    validUntil: _readNullableDate(row['valid_until']),
    sourcePath: row['source_path'] as String?,
  );
}

BackupInfo _backupFromRow(Map<String, Object?> row) {
  return BackupInfo(
    backupId: row['backup_id']! as String,
    createdAt: _readDate(row['created_at']),
    path: row['path']! as String,
    checksum: row['checksum']! as String,
    businessId: row['business_id'] as String?,
  );
}

int _date(DateTime value) => value.toUtc().millisecondsSinceEpoch;

int? _nullableDate(DateTime? value) => value == null ? null : _date(value);

DateTime _readDate(Object? value) {
  return DateTime.fromMillisecondsSinceEpoch(value! as int, isUtc: true);
}

DateTime? _readNullableDate(Object? value) {
  return value == null ? null : _readDate(value);
}

int _bool(bool value) => value ? 1 : 0;

bool _readBool(Object? value) => value == 1;

CardStatus _status(Object? value) {
  return CardStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => CardStatus.draft,
  );
}

CustomerStatus _customerStatus(Object? value) {
  return CustomerStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => CustomerStatus.active,
  );
}

SubscriptionType _subscriptionType(Object? value) {
  return SubscriptionType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => SubscriptionType.custom,
  );
}

LoyaltyProgramType _loyaltyProgramType(Object? value) {
  return LoyaltyProgramType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => LoyaltyProgramType.stamps,
  );
}

AppMode? _mode(String? value) {
  if (value == null) {
    return null;
  }

  return AppMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppMode.business,
  );
}

ClientCardsViewMode _clientCardsViewMode(String? value) {
  return ClientCardsViewMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ClientCardsViewMode.list,
  );
}

BusinessClientsViewMode _businessClientsViewMode(String? value) {
  return BusinessClientsViewMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => BusinessClientsViewMode.list,
  );
}

AppZoomMode _zoomMode(String? value) {
  return AppZoomMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppZoomMode.normal,
  );
}
