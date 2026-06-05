import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/repositories/drift_repositories.dart';
import 'package:fidelio/domain/entities/entities.dart';
import 'package:fidelio/domain/value_objects/app_mode.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';
import 'package:fidelio/domain/value_objects/loyalty_program_type.dart';
import 'package:fidelio/domain/value_objects/subscription_type.dart';

void main() {
  late AppDatabase db;
  late DriftAppSettingsRepository appSettings;
  late DriftBusinessRepository businesses;
  late DriftCustomerRepository customers;
  late DriftCardRepository cards;
  late DriftWalletRepository wallet;
  late DriftCheckInRepository checkIns;
  late DriftLoyaltyTransactionRepository transactions;
  late DriftLicenseRepository licenses;
  late DriftBackupRepository backups;

  final now = DateTime.utc(2026, 5, 12, 10);

  setUp(() {
    db = AppDatabase.memory();
    appSettings = DriftAppSettingsRepository(db);
    businesses = DriftBusinessRepository(db);
    customers = DriftCustomerRepository(db);
    cards = DriftCardRepository(db);
    wallet = DriftWalletRepository(db);
    checkIns = DriftCheckInRepository(db);
    transactions = DriftLoyaltyTransactionRepository(db);
    licenses = DriftLicenseRepository(db);
    backups = DriftBackupRepository(db);
  });

  tearDown(() => db.close());

  test('app settings persist the selected app mode', () async {
    expect((await appSettings.loadSettings()).selectedMode, isNull);
    expect(
      (await appSettings.loadSettings()).clientCardsViewMode,
      ClientCardsViewMode.list,
    );
    expect(
      (await appSettings.loadSettings()).businessClientsViewMode,
      BusinessClientsViewMode.list,
    );
    expect((await appSettings.loadSettings()).zoomMode, AppZoomMode.normal);
    expect((await appSettings.loadSettings()).darkMode, isFalse);

    await appSettings.saveSelectedMode(AppMode.business);
    expect((await appSettings.loadSettings()).selectedMode, AppMode.business);

    await appSettings.saveSelectedMode(AppMode.client);
    expect((await appSettings.loadSettings()).selectedMode, AppMode.client);

    await appSettings.saveClientCardsViewMode(ClientCardsViewMode.grid);
    await appSettings.saveBusinessClientsViewMode(BusinessClientsViewMode.grid);
    await appSettings.saveZoomMode(AppZoomMode.large);
    await appSettings.saveDarkMode(true);
    final updatedSettings = await appSettings.loadSettings();
    expect(updatedSettings.clientCardsViewMode, ClientCardsViewMode.grid);
    expect(
      updatedSettings.businessClientsViewMode,
      BusinessClientsViewMode.grid,
    );
    expect(updatedSettings.zoomMode, AppZoomMode.large);
    expect(updatedSettings.darkMode, isTrue);

    await appSettings.clearSelectedMode();
    final clearedSettings = await appSettings.loadSettings();
    expect(clearedSettings.selectedMode, isNull);
    expect(clearedSettings.clientCardsViewMode, ClientCardsViewMode.grid);
    expect(
      clearedSettings.businessClientsViewMode,
      BusinessClientsViewMode.grid,
    );
    expect(clearedSettings.zoomMode, AppZoomMode.large);
    expect(clearedSettings.darkMode, isTrue);
  });

  test('business profiles can be created, read, updated and deleted', () async {
    await businesses.saveBusinessProfile(
      BusinessProfile(
        businessId: 'business-1',
        displayName: 'Coffee Shop',
        createdAt: now,
      ),
    );

    expect((await businesses.getActiveBusiness())?.displayName, 'Coffee Shop');

    await businesses.saveBusinessProfile(
      BusinessProfile(
        businessId: 'business-1',
        displayName: 'Updated Shop',
        createdAt: now,
        activityDomain: 'Retail',
        phone: '0712345678',
        email: 'test@example.com',
        address: 'Strada Locala 1',
        cardAccentColor: 0xFF2563EB,
        activitySymbol: 'robotics',
        localPublicKey: 'public-key',
      ),
    );

    final updated = await businesses.getBusinessProfile('business-1');
    expect(updated?.displayName, 'Updated Shop');
    expect(updated?.activityDomain, 'Retail');
    expect(updated?.phone, '0712345678');
    expect(updated?.email, 'test@example.com');
    expect(updated?.address, 'Strada Locala 1');
    expect(updated?.cardAccentColor, 0xFF2563EB);
    expect(updated?.activitySymbol, 'robotics');
    expect(updated?.localPublicKey, 'public-key');

    await businesses.deleteBusinessProfile('business-1');
    expect(await businesses.getBusinessProfile('business-1'), isNull);
  });

  test('customer records can be created, read, updated and deleted', () async {
    await customers.saveCustomer(
      CustomerRecord(
        customerId: 'customer-1',
        businessId: 'business-1',
        createdAt: now,
        updatedAt: now,
        displayName: 'Ana',
      ),
    );

    expect(await customers.listCustomers('business-1'), hasLength(1));

    await customers.saveCustomer(
      CustomerRecord(
        customerId: 'customer-1',
        businessId: 'business-1',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
        displayName: 'Ana Updated',
        phone: '0712345678',
        email: 'ana@example.com',
        notes: 'local note',
      ),
    );

    final updated = await customers.getCustomer('customer-1');
    expect(updated?.displayName, 'Ana Updated');
    expect(updated?.phone, '0712345678');
    expect(updated?.email, 'ana@example.com');
    expect(updated?.notes, 'local note');

    await customers.saveCustomer(
      CustomerRecord(
        customerId: 'customer-2',
        businessId: 'business-1',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 2)),
        displayName: '0712349999',
        phone: 'Ana phone note',
      ),
    );
    final searchResults = await customers.searchCustomers('business-1', 'Ana');
    expect(searchResults.first.customerId, 'customer-2');

    await customers.deleteCustomer('customer-1');
    expect(await customers.getCustomer('customer-1'), isNull);
  });

  test('subscription and loyalty cards support CRUD', () async {
    await cards.saveSubscriptionCard(
      SubscriptionCard(
        businessId: 'business-1',
        cardId: 'subscription-1',
        customerId: 'customer-1',
        name: '10 entries',
        createdAt: now,
        status: CardStatus.active,
        subscriptionType: SubscriptionType.entries,
        startsAt: now,
        expiresAt: now.add(const Duration(days: 30)),
        remainingUses: 10,
        linkedWalletId: 'wallet-1',
        notes: 'test subscription',
      ),
    );
    await cards.saveLoyaltyCard(
      LoyaltyCard(
        businessId: 'business-1',
        cardId: 'loyalty-1',
        customerId: 'customer-1',
        name: 'Coffee stamps',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 2,
        rewardThreshold: 8,
        programType: LoyaltyProgramType.points,
        pointsPerScan: 15,
        linkedWalletId: 'wallet-1',
      ),
    );

    expect(await cards.listSubscriptionCards('business-1'), hasLength(1));
    expect(
      await cards.listSubscriptionCardsForCustomer('customer-1'),
      hasLength(1),
    );
    expect(await cards.listLoyaltyCards('business-1'), hasLength(1));

    await cards.saveSubscriptionCard(
      SubscriptionCard(
        businessId: 'business-1',
        cardId: 'subscription-1',
        customerId: 'customer-1',
        name: '10 entries',
        createdAt: now,
        status: CardStatus.active,
        subscriptionType: SubscriptionType.entries,
        startsAt: now,
        expiresAt: now.add(const Duration(days: 30)),
        remainingUses: 7,
        linkedWalletId: 'wallet-2',
        notes: 'updated subscription',
      ),
    );
    await cards.saveLoyaltyCard(
      LoyaltyCard(
        businessId: 'business-1',
        cardId: 'loyalty-1',
        customerId: 'customer-1',
        name: 'Coffee stamps',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 3,
        rewardThreshold: 8,
        programType: LoyaltyProgramType.visitChallenge,
        challengeWindowDays: 7,
        challengeStartedAt: now,
        linkedWalletId: 'wallet-2',
      ),
    );

    expect(
      (await cards.getSubscriptionCard('subscription-1'))?.remainingUses,
      7,
    );
    expect(
      (await cards.getSubscriptionCard('subscription-1'))?.subscriptionType,
      SubscriptionType.entries,
    );
    expect(
      (await cards.getSubscriptionCard('subscription-1'))?.notes,
      'updated subscription',
    );
    expect(
      (await cards.getSubscriptionCard('subscription-1'))?.linkedWalletId,
      'wallet-2',
    );
    expect((await cards.getLoyaltyCard('loyalty-1'))?.currentStamps, 3);
    expect(
      (await cards.getLoyaltyCard('loyalty-1'))?.programType,
      LoyaltyProgramType.visitChallenge,
    );
    expect((await cards.getLoyaltyCard('loyalty-1'))?.challengeWindowDays, 7);
    expect((await cards.getLoyaltyCard('loyalty-1'))?.challengeStartedAt, now);
    expect(
      (await cards.getLoyaltyCard('loyalty-1'))?.linkedWalletId,
      'wallet-2',
    );

    await cards.deleteSubscriptionCard('subscription-1');
    await cards.deleteLoyaltyCard('loyalty-1');
    expect(await cards.getSubscriptionCard('subscription-1'), isNull);
    expect(await cards.getLoyaltyCard('loyalty-1'), isNull);
  });

  test('wallet cards can be created, read, updated and deleted', () async {
    await wallet.saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: 'wallet-1',
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: '10 entries',
        createdAt: now,
        status: CardStatus.active,
        businessName: 'Coffee Shop',
        businessDomain: 'Coffee',
        businessSymbol: 'coffee',
        businessAccentColor: 0xFF2563EB,
        scanValue: 1,
      ),
    );

    expect(await wallet.listWalletCards('wallet-1'), hasLength(1));

    await wallet.saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: 'wallet-1',
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: 'Updated entries',
        createdAt: now,
        status: CardStatus.suspended,
      ),
    );

    final updated = await wallet.getWalletCard('wallet-card-1');
    expect(updated?.displayName, 'Updated entries');
    expect(updated?.status, CardStatus.suspended);
    expect(updated?.businessName, isNull);
    expect(updated?.businessDomain, isNull);
    expect(updated?.businessSymbol, isNull);
    expect(updated?.scanValue, isNull);

    await wallet.deleteWalletCard('wallet-card-1');
    expect(await wallet.getWalletCard('wallet-card-1'), isNull);
  });

  test(
    'check-ins, loyalty transactions, licenses and backups support CRUD',
    () async {
      await checkIns.saveCheckIn(
        CheckInEvent(
          eventId: 'event-1',
          businessId: 'business-1',
          cardId: 'card-1',
          occurredAt: now,
          challengeTimestamp: now,
          signature: 'test-signature',
          result: 'accepted',
        ),
      );
      await transactions.saveTransaction(
        LoyaltyTransaction(
          transactionId: 'transaction-1',
          businessId: 'business-1',
          cardId: 'card-1',
          createdAt: now,
          stampDelta: 1,
        ),
      );
      await licenses.saveLicense(
        LicenseInfo(
          licenseId: 'license-1',
          businessId: 'business-1',
          issuedAt: now,
          isLifetime: false,
          signature: 'license-signature',
          validUntil: now.add(const Duration(days: 30)),
        ),
      );
      await backups.saveBackup(
        BackupInfo(
          backupId: 'backup-1',
          createdAt: now,
          path: 'local/path',
          checksum: 'checksum',
          businessId: 'business-1',
        ),
      );

      expect(await checkIns.listCheckIns('business-1'), hasLength(1));
      expect(await transactions.listTransactions('card-1'), hasLength(1));
      expect(await licenses.listLicenses('business-1'), hasLength(1));
      expect(await backups.listBackups('business-1'), hasLength(1));

      await checkIns.saveCheckIn(
        CheckInEvent(
          eventId: 'event-1',
          businessId: 'business-1',
          cardId: 'card-1',
          occurredAt: now,
          challengeTimestamp: now,
          signature: 'updated-signature',
          result: 'accepted',
        ),
      );
      await transactions.saveTransaction(
        LoyaltyTransaction(
          transactionId: 'transaction-1',
          businessId: 'business-1',
          cardId: 'card-1',
          createdAt: now,
          stampDelta: 2,
          rewardIssued: true,
        ),
      );
      await licenses.saveLicense(
        LicenseInfo(
          licenseId: 'license-1',
          businessId: 'business-1',
          issuedAt: now,
          isLifetime: true,
          signature: 'updated-license-signature',
        ),
      );
      await backups.saveBackup(
        BackupInfo(
          backupId: 'backup-1',
          createdAt: now,
          path: 'updated/path',
          checksum: 'updated-checksum',
          businessId: 'business-1',
        ),
      );

      expect(
        (await checkIns.getCheckIn('event-1'))?.signature,
        'updated-signature',
      );
      expect(
        (await transactions.getTransaction('transaction-1'))?.stampDelta,
        2,
      );
      expect((await licenses.getLicense('license-1'))?.isLifetime, isTrue);
      expect((await backups.getBackup('backup-1'))?.path, 'updated/path');

      await checkIns.deleteCheckIn('event-1');
      await transactions.deleteTransaction('transaction-1');
      await licenses.deleteLicense('license-1');
      await backups.deleteBackup('backup-1');

      expect(await checkIns.getCheckIn('event-1'), isNull);
      expect(await transactions.getTransaction('transaction-1'), isNull);
      expect(await licenses.getLicense('license-1'), isNull);
      expect(await backups.getBackup('backup-1'), isNull);
    },
  );

  test('valid check-ins reject duplicate dynamic QR signatures', () async {
    final firstEvent = CheckInEvent(
      eventId: 'event-1',
      businessId: 'business-1',
      cardId: 'card-1',
      occurredAt: now,
      challengeTimestamp: now,
      signature: 'dynamic-signature',
      result: 'valid',
    );
    final duplicateEvent = CheckInEvent(
      eventId: 'event-2',
      businessId: 'business-1',
      cardId: 'card-1',
      occurredAt: now.add(const Duration(seconds: 1)),
      challengeTimestamp: now,
      signature: 'dynamic-signature',
      result: 'valid',
    );

    await checkIns.saveCheckIn(firstEvent);

    expect(
      await checkIns.hasValidCheckInForSignature(
        businessId: 'business-1',
        cardId: 'card-1',
        signature: 'dynamic-signature',
      ),
      isTrue,
    );
    expect(() => checkIns.saveCheckIn(duplicateEvent), throwsA(anything));
  });
}
