import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fidelio/app/app.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/client_wallet_providers.dart';
import 'package:fidelio/app/providers/license_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/repositories/drift_repositories.dart';
import 'package:fidelio/domain/entities/app_settings.dart';
import 'package:fidelio/domain/entities/business_profile.dart';
import 'package:fidelio/domain/entities/customer_record.dart';
import 'package:fidelio/domain/entities/license_status.dart';
import 'package:fidelio/domain/entities/loyalty_card.dart';
import 'package:fidelio/domain/entities/subscription_card.dart';
import 'package:fidelio/domain/entities/wallet_card.dart';
import 'package:fidelio/domain/value_objects/app_mode.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';
import 'package:fidelio/domain/value_objects/loyalty_program_type.dart';
import 'package:fidelio/domain/value_objects/subscription_type.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _testClientWalletId = 'wallet-test';

void main() {
  testWidgets('shows mode selection screen', (WidgetTester tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clientWalletIdProvider.overrideWith(
            (ref) async => _testClientWalletId,
          ),
        ],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fidelio'), findsOneWidget);
    expect(find.text('Choose how to use the app'), findsOneWidget);
    expect(find.text('Use as Business'), findsOneWidget);
    expect(find.text('Use as Client'), findsOneWidget);
  });

  testWidgets('saved business mode without profile shows setup', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.business);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set Up Business'), findsOneWidget);
    expect(find.text('Choose how to use the app'), findsNothing);
  });

  testWidgets('saved business mode with profile starts in dashboard', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.business);
    await DriftBusinessRepository(db).saveBusinessProfile(
      BusinessProfile(
        businessId: 'business-1',
        displayName: 'Coffee Shop',
        createdAt: DateTime.utc(2026, 5, 12),
        activityDomain: 'Coffee',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Business Mode'), findsOneWidget);
    expect(find.text('Set Up Business'), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Recent Scans'), findsOneWidget);
    expect(find.text('Create Membership'), findsNothing);
    expect(find.text('Create Loyalty Card'), findsNothing);
  });

  testWidgets(
    'client home shows only wallet cards import and settings actions',
    (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.client);
      await DriftWalletRepository(db).saveWalletCard(
        WalletCard(
          walletCardId: 'wallet-card-1',
          walletId: _testClientWalletId,
          businessId: 'business-1',
          cardId: 'subscription-1',
          cardType: 'subscription',
          displayName: '10 entries',
          createdAt: DateTime.utc(2026, 5, 13),
          status: CardStatus.active,
          businessName: 'Coffee Shop',
          entriesTotal: 10,
          entriesRemaining: 8,
          validUntil: DateTime.utc(2026, 6, 13),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            clientWalletIdProvider.overrideWith(
              (ref) async => _testClientWalletId,
            ),
          ],
          child: const LocalLoyaltyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Cards'), findsOneWidget);
      expect(find.text('Import Card'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Portofel'), findsNothing);
      expect(find.text('Dynamic QR'), findsNothing);
    },
  );

  testWidgets('client settings control view zoom and dark mode', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.client);
    await DriftAppSettingsRepository(
      db,
    ).saveClientWalletId(_testClientWalletId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Card View'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Zoom'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Wallet ID'), findsOneWidget);
    expect(find.text(_testClientWalletId), findsOneWidget);
    expect(find.byTooltip('Copy Wallet ID'), findsOneWidget);

    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final settings = await DriftAppSettingsRepository(db).loadSettings();
    expect(settings.clientCardsViewMode, ClientCardsViewMode.grid);
    expect(settings.zoomMode, AppZoomMode.large);
    expect(settings.darkMode, isTrue);
  });

  testWidgets('client cards use grid view setting', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final settingsRepository = DriftAppSettingsRepository(db);
    await settingsRepository.saveSelectedMode(AppMode.client);
    await settingsRepository.saveClientCardsViewMode(ClientCardsViewMode.grid);
    await DriftWalletRepository(db).saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: _testClientWalletId,
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: '10 entries',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        businessName: 'Coffee Shop',
        entriesTotal: 10,
        entriesRemaining: 8,
        scanValue: 1,
        validUntil: DateTime.utc(2026, 6, 13),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clientWalletIdProvider.overrideWith(
            (ref) async => _testClientWalletId,
          ),
        ],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cards'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('10 entries'), findsOneWidget);
  });

  testWidgets('business creates subscription from client details', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Client'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Membership'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final subscriptions = await DriftCardRepository(
      db,
    ).listSubscriptionCards('business-1');
    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.customerId, 'customer-1');
    expect(find.text('Membership monthly'), findsOneWidget);
  });

  testWidgets('business creates loyalty card from client details', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Client'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Loyalty Card'));
    await tester.pumpAndSettle();

    expect(find.text('Loyalty Program Type'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final loyaltyCards = await DriftCardRepository(
      db,
    ).listLoyaltyCards('business-1');
    expect(loyaltyCards, hasLength(1));
    expect(loyaltyCards.single.customerId, 'customer-1');
    expect(loyaltyCards.single.rewardThreshold, 8);
    expect(loyaltyCards.single.programType, LoyaltyProgramType.stamps);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Loyalty Card'), findsOneWidget);
    expect(find.text('0/8 stamps'), findsOneWidget);
  });

  testWidgets('business creates delivery loyalty card from client details', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Client'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Loyalty Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stamps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delivery').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final loyaltyCards = await DriftCardRepository(
      db,
    ).listLoyaltyCards('business-1');
    expect(loyaltyCards, hasLength(1));
    expect(loyaltyCards.single.programType, LoyaltyProgramType.delivery);
    expect(loyaltyCards.single.rewardThreshold, 5);
  });

  testWidgets(
    'business delivery loyalty details adds stamp without QR or NFC',
    (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedBusinessWithCustomer(db);
      await DriftCardRepository(db).saveLoyaltyCard(
        LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-delivery-1',
          customerId: 'customer-1',
          name: 'Delivery Pizza',
          createdAt: DateTime.utc(2026, 5, 19),
          status: CardStatus.active,
          currentStamps: 4,
          rewardThreshold: 5,
          programType: LoyaltyProgramType.delivery,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            clientWalletIdProvider.overrideWith(
              (ref) async => _testClientWalletId,
            ),
          ],
          child: const LocalLoyaltyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Client'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery Pizza'));
      await tester.pumpAndSettle();

      expect(find.text('Send to Client by QR'), findsNothing);
      expect(find.text('Send to Client by NFC'), findsNothing);
      expect(find.text('Add Stamp'), findsOneWidget);

      await tester.tap(find.text('Add Stamp'));
      await tester.pumpAndSettle();

      final updated = await DriftCardRepository(
        db,
      ).getLoyaltyCard('loyalty-delivery-1');
      expect(updated?.currentStamps, 5);
      expect(
        find.text('Stamp added. Progress: 5/5. Reward available.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Redeem Reward'));
      await tester.pumpAndSettle();
      expect(find.text('Redeem reward?'), findsOneWidget);
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();

      final redeemed = await DriftCardRepository(
        db,
      ).getLoyaltyCard('loyalty-delivery-1');
      expect(redeemed?.currentStamps, 0);
    },
  );

  testWidgets(
    'business membership save shows license message after free limit',
    (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedBusinessWithCustomer(db);
      await _seedFreeLimitCards(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const LocalLoyaltyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Client'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Membership'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('License required'), findsOneWidget);
      expect(find.textContaining('voltacademy007@gmail.com'), findsOneWidget);
      expect(
        await DriftCardRepository(db).listSubscriptionCards('business-1'),
        hasLength(10),
      );
    },
  );

  testWidgets('business loyalty save shows license message after free limit', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);
    await _seedFreeLimitCards(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Client'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Loyalty Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('License required'), findsOneWidget);
    expect(find.textContaining('voltacademy007@gmail.com'), findsOneWidget);
    expect(
      await DriftCardRepository(db).listLoyaltyCards('business-1'),
      isEmpty,
    );
  });

  testWidgets('business deletes customer from client details', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Client'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Customer'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Are you sure you want to permanently delete this customer from the local database?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await DriftCustomerRepository(db).getCustomer('customer-1'), isNull);
  });

  testWidgets('business settings exposes company data section', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Business Details'), findsOneWidget);
    expect(find.text('Business Name'), findsNothing);

    await tester.tap(find.text('Business Details'));
    await tester.pumpAndSettle();

    expect(find.text('Business Name'), findsOneWidget);
    expect(find.text('Activity Symbol'), findsOneWidget);
    expect(find.text('Card Color'), findsOneWidget);
    expect(find.text('Default'), findsWidgets);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('business settings control view zoom and dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Customer View'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Zoom'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);

    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final settings = await DriftAppSettingsRepository(db).loadSettings();
    expect(settings.businessClientsViewMode, BusinessClientsViewMode.grid);
    expect(settings.zoomMode, AppZoomMode.large);
    expect(settings.darkMode, isTrue);
  });

  testWidgets('business clients use grid view setting', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);
    await DriftAppSettingsRepository(
      db,
    ).saveBusinessClientsViewMode(BusinessClientsViewMode.grid);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Ana Client'), findsOneWidget);
  });

  testWidgets('business can create customer with phone only', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedBusinessWithCustomer(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Customer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '0711111111');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final customers = await DriftCustomerRepository(
      db,
    ).searchCustomers('business-1', '0711111111');
    expect(customers.single.displayName, '0711111111');
    expect(customers.single.phone, '0711111111');
  });

  testWidgets('client card details opens dynamic QR access page', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.client);
    await DriftWalletRepository(db).saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: _testClientWalletId,
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: '10 entries',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        businessName: 'Coffee Shop',
        entriesTotal: 10,
        entriesRemaining: 8,
        validUntil: DateTime.utc(2026, 6, 13),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clientWalletIdProvider.overrideWith(
            (ref) async => _testClientWalletId,
          ),
        ],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 entries'));
    await tester.pumpAndSettle();
    expect(find.text('Update my card'), findsNothing);

    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('QR Access'), findsOneWidget);
    expect(find.text('Show this code for scanning.'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'After the business scans this access code, tap Update to refresh this phone wallet locally.',
      ),
      findsOneWidget,
    );
    expect(find.text('Update local card'), findsOneWidget);
  });

  testWidgets('client can update a wallet card locally after check-in', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.client);
    await DriftWalletRepository(db).saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: _testClientWalletId,
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: '10 entries',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        businessName: 'Coffee Shop',
        entriesTotal: 10,
        entriesRemaining: 8,
        scanValue: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clientWalletIdProvider.overrideWith(
            (ref) async => _testClientWalletId,
          ),
        ],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 entries'));
    await tester.pumpAndSettle();
    expect(find.text('Update my card'), findsNothing);

    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update local card'));
    await tester.pumpAndSettle();

    expect(find.text('Card Details'), findsOneWidget);
    expect(
      (await DriftWalletRepository(
        db,
      ).getWalletCard('wallet-card-1'))?.entriesRemaining,
      7,
    );
  });

  testWidgets('client can delete a wallet card', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.client);
    await DriftWalletRepository(db).saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: _testClientWalletId,
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: '10 entries',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        businessName: 'Coffee Shop',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clientWalletIdProvider.overrideWith(
            (ref) async => _testClientWalletId,
          ),
        ],
        child: const LocalLoyaltyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 entries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      await DriftWalletRepository(db).getWalletCard('wallet-card-1'),
      isNull,
    );
  });

  testWidgets(
    'business membership shows expiry warning snackbar when license expires soon',
    (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedBusinessWithCustomer(db);
      await _seedFreeLimitCards(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            businessLicenseStatusProvider.overrideWith(
              (ref, businessId) async => const LicenseStatus(
                state: LicenseState.active,
                message: 'License active. 5 days remaining.',
                isLifetime: false,
                daysUntilExpiry: 5,
                validUntil: '2026-06-29T00:00:00Z',
              ),
            ),
          ],
          child: const LocalLoyaltyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Membership'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('License required'), findsNothing);
      expect(
        find.textContaining('License expires in 5 days'),
        findsOneWidget,
      );
      expect(
        await DriftCardRepository(db).listSubscriptionCards('business-1'),
        hasLength(11),
      );
    },
  );

  testWidgets(
    'business loyalty card shows tomorrow expiry warning when 1 day remains',
    (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedBusinessWithCustomer(db);
      await _seedFreeLimitCards(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            businessLicenseStatusProvider.overrideWith(
              (ref, businessId) async => const LicenseStatus(
                state: LicenseState.active,
                message: 'License expires tomorrow.',
                isLifetime: false,
                daysUntilExpiry: 1,
                validUntil: '2026-06-25T00:00:00Z',
              ),
            ),
          ],
          child: const LocalLoyaltyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Loyalty Card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('License required'), findsNothing);
      expect(find.textContaining('expires tomorrow'), findsOneWidget);
      expect(
        await DriftCardRepository(db).listLoyaltyCards('business-1'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'business membership does not show expiry warning when license has 11 days remaining',
    (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedBusinessWithCustomer(db);
      await _seedFreeLimitCards(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            businessLicenseStatusProvider.overrideWith(
              (ref, businessId) async => const LicenseStatus(
                state: LicenseState.active,
                message: 'License active. 11 days remaining.',
                isLifetime: false,
                daysUntilExpiry: 11,
                validUntil: '2026-07-05T00:00:00Z',
              ),
            ),
          ],
          child: const LocalLoyaltyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Membership'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('License required'), findsNothing);
      expect(find.textContaining('expires in'), findsNothing);
      expect(find.textContaining('expires tomorrow'), findsNothing);
      expect(
        await DriftCardRepository(db).listSubscriptionCards('business-1'),
        hasLength(11),
      );
    },
  );
}

Future<void> _seedBusinessWithCustomer(AppDatabase db) async {
  await DriftAppSettingsRepository(db).saveSelectedMode(AppMode.business);
  await DriftBusinessRepository(db).saveBusinessProfile(
    BusinessProfile(
      businessId: 'business-1',
      displayName: 'Coffee Shop',
      createdAt: DateTime.utc(2026, 5, 13),
    ),
  );
  await DriftCustomerRepository(db).saveCustomer(
    CustomerRecord(
      customerId: 'customer-1',
      businessId: 'business-1',
      createdAt: DateTime.utc(2026, 5, 13),
      updatedAt: DateTime.utc(2026, 5, 13),
      displayName: 'Ana Client',
    ),
  );
}

Future<void> _seedFreeLimitCards(AppDatabase db) async {
  final repository = DriftCardRepository(db);
  for (var index = 0; index < 10; index += 1) {
    await repository.saveSubscriptionCard(
      SubscriptionCard(
        businessId: 'business-1',
        cardId: 'subscription-$index',
        customerId: 'customer-1',
        name: 'Membership $index',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        subscriptionType: SubscriptionType.monthly,
        startsAt: DateTime.utc(2026, 5, 13),
        expiresAt: DateTime.utc(2026, 6, 13),
        validUntil: DateTime.utc(2026, 6, 13),
      ),
    );
  }
}
