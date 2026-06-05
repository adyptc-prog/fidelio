import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/client_wallet_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/repositories/drift_repositories.dart';
import 'package:fidelio/domain/entities/subscription_import_payload.dart';
import 'package:fidelio/domain/entities/wallet_card.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';

void main() {
  test('imports loyalty payload as loyalty wallet card', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final importedCard = await container
        .read(clientWalletImportControllerProvider)
        .importPayload(
          SubscriptionImportPayload(
            type: 'subscription_card_import',
            version: 1,
            businessId: 'business-1',
            businessName: 'Coffee Shop',
            businessDomain: 'Coffee',
            businessSymbol: 'coffee',
            businessAccentColor: 0xFF2563EB,
            clientId: 'customer-1',
            subscriptionId: 'loyalty-1',
            cardTitle: 'Coffee Loyalty',
            validFrom: DateTime.utc(2026, 5, 13),
            validUntil: DateTime.utc(2027, 5, 13),
            issuedAt: DateTime.utc(2026, 5, 13),
            cardType: 'loyalty',
          ),
          updateExisting: true,
        );

    expect(importedCard?.cardType, 'loyalty');
    expect(importedCard?.walletId, startsWith('wallet-'));
    expect(
      importedCard?.walletId,
      await container.read(clientWalletIdProvider.future),
    );
    final cards = await DriftWalletRepository(
      db,
    ).listWalletCards(importedCard!.walletId);
    expect(cards, hasLength(1));
    expect(cards.single.cardType, 'loyalty');
    expect(cards.single.businessDomain, 'Coffee');
    expect(cards.single.businessSymbol, 'coffee');
    expect(cards.single.businessAccentColor, 0xFF2563EB);
  });

  test('updates subscription wallet card locally after a visit', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await DriftWalletRepository(db).saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: 'wallet-test',
        businessId: 'business-1',
        cardId: 'subscription-1',
        cardType: 'subscription',
        displayName: '10 entries',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        entriesTotal: 10,
        entriesRemaining: 3,
        scanValue: 1,
      ),
    );

    final updated = await container
        .read(clientWalletImportControllerProvider)
        .updateMyCard('wallet-card-1');

    expect(updated?.entriesRemaining, 2);
    expect(
      (await DriftWalletRepository(
        db,
      ).getWalletCard('wallet-card-1'))?.entriesRemaining,
      2,
    );
  });

  test('updates loyalty wallet card locally using scan value', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await DriftWalletRepository(db).saveWalletCard(
      WalletCard(
        walletCardId: 'wallet-card-1',
        walletId: 'wallet-test',
        businessId: 'business-1',
        cardId: 'loyalty-1',
        cardType: 'loyalty',
        displayName: 'Points club',
        createdAt: DateTime.utc(2026, 5, 13),
        status: CardStatus.active,
        entriesTotal: 100,
        entriesRemaining: 80,
        scanValue: 15,
      ),
    );

    final updated = await container
        .read(clientWalletImportControllerProvider)
        .updateMyCard('wallet-card-1');

    expect(updated?.entriesRemaining, 65);
  });
}
