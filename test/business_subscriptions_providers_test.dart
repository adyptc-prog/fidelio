import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/business_subscriptions_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/repositories/drift_repositories.dart';
import 'package:fidelio/domain/entities/business_profile.dart';
import 'package:fidelio/domain/entities/customer_record.dart';
import 'package:fidelio/domain/entities/loyalty_card.dart';
import 'package:fidelio/domain/value_objects/loyalty_program_type.dart';

void main() {
  group('BusinessSubscriptionActions loyalty card validity', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      await DriftBusinessRepository(db).saveBusinessProfile(
        BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test(
      'createLoyaltyCard defaults startsAt to now and leaves validUntil null',
      () async {
        final before = DateTime.now();
        await container
            .read(businessSubscriptionActionsProvider)
            .createLoyaltyCard(
              businessId: 'business-1',
              customerId: 'customer-1',
              name: 'Coffee Loyalty',
              rewardThreshold: 8,
            );
        final after = DateTime.now();

        final cards = await DriftCardRepository(
          db,
        ).listLoyaltyCards('business-1');
        expect(cards, hasLength(1));
        final card = cards.single;
        expect(card.startsAt, isNotNull);
        expect(
          card.startsAt!.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          card.startsAt!.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
        expect(card.validUntil, isNull);
      },
    );

    test('createLoyaltyCard stores explicit startsAt and validUntil', () async {
      final startsAt = DateTime.utc(2026, 1, 1);
      final validUntil = DateTime.utc(2026, 12, 31);

      await container
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: 'business-1',
            customerId: 'customer-1',
            name: 'Coffee Loyalty',
            rewardThreshold: 8,
            programType: LoyaltyProgramType.stamps,
            startsAt: startsAt,
            validUntil: validUntil,
          );

      final cards = await DriftCardRepository(
        db,
      ).listLoyaltyCards('business-1');
      expect(cards.single.startsAt, startsAt);
      expect(cards.single.validUntil, validUntil);
    });

    test('updateLoyaltyCardValidity persists new dates', () async {
      await container
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: 'business-1',
            customerId: 'customer-1',
            name: 'Coffee Loyalty',
            rewardThreshold: 8,
          );
      final created = (await DriftCardRepository(
        db,
      ).listLoyaltyCards('business-1')).single;

      final newStartsAt = DateTime.utc(2026, 3, 1);
      final newValidUntil = DateTime.utc(2026, 6, 1);
      final updated = await container
          .read(businessSubscriptionActionsProvider)
          .updateLoyaltyCardValidity(
            loyaltyCardId: created.cardId,
            startsAt: newStartsAt,
            validUntil: newValidUntil,
          );

      expect(updated?.startsAt, newStartsAt);
      expect(updated?.validUntil, newValidUntil);

      final reloaded = await DriftCardRepository(
        db,
      ).getLoyaltyCard(created.cardId);
      expect(reloaded?.startsAt, newStartsAt);
      expect(reloaded?.validUntil, newValidUntil);
    });

    test('updateLoyaltyCardValidity can clear the expiration date', () async {
      await container
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: 'business-1',
            customerId: 'customer-1',
            name: 'Coffee Loyalty',
            rewardThreshold: 8,
            validUntil: DateTime.utc(2026, 6, 1),
          );
      final created = (await DriftCardRepository(
        db,
      ).listLoyaltyCards('business-1')).single;

      final updated = await container
          .read(businessSubscriptionActionsProvider)
          .updateLoyaltyCardValidity(
            loyaltyCardId: created.cardId,
            startsAt: created.startsAt!,
          );

      expect(updated?.validUntil, isNull);
    });
  });

  group('BusinessSubscriptionActions.grantBonusEntry', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      await DriftBusinessRepository(db).saveBusinessProfile(
        BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: DateTime.now(),
        ),
      );
      await DriftCustomerRepository(db).saveCustomer(
        CustomerRecord(
          customerId: 'customer-1',
          businessId: 'business-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          displayName: 'Ana Client',
        ),
      );
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test(
      'consuming the bonus entry increments the customer reward count',
      () async {
        await container
            .read(businessSubscriptionActionsProvider)
            .createLoyaltyCard(
              businessId: 'business-1',
              customerId: 'customer-1',
              name: 'Coffee Loyalty',
              rewardThreshold: 1,
            );
        final created = (await DriftCardRepository(
          db,
        ).listLoyaltyCards('business-1')).single;
        final actions = container.read(businessSubscriptionActionsProvider);

        await actions.grantBonusEntry(created.cardId);
        expect(
          (await DriftCustomerRepository(
            db,
          ).getCustomer('customer-1'))?.rewardsEarned,
          0,
        );

        await actions.grantBonusEntry(created.cardId);
        expect(
          (await DriftCustomerRepository(
            db,
          ).getCustomer('customer-1'))?.rewardsEarned,
          1,
        );
      },
    );

    test('adds one stamp for a stamps-based card', () async {
      await container
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: 'business-1',
            customerId: 'customer-1',
            name: 'Coffee Loyalty',
            rewardThreshold: 8,
          );
      final created = (await DriftCardRepository(
        db,
      ).listLoyaltyCards('business-1')).single;

      final updated = await container
          .read(businessSubscriptionActionsProvider)
          .grantBonusEntry(created.cardId);

      expect(updated?.currentStamps, 1);
    });

    test('returns null for an unknown card id', () async {
      final updated = await container
          .read(businessSubscriptionActionsProvider)
          .grantBonusEntry('does-not-exist');

      expect(updated, isNull);
    });

    test('does not advance an already completed card', () async {
      await container
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: 'business-1',
            customerId: 'customer-1',
            name: 'Delivery Pizza',
            rewardThreshold: 5,
            programType: LoyaltyProgramType.delivery,
          );
      final created = (await DriftCardRepository(
        db,
      ).listLoyaltyCards('business-1')).single;
      final repository = DriftCardRepository(db);
      await repository.saveLoyaltyCard(
        LoyaltyCard(
          businessId: created.businessId,
          cardId: created.cardId,
          customerId: created.customerId,
          name: created.name,
          createdAt: created.createdAt,
          status: created.status,
          currentStamps: created.currentStamps,
          rewardThreshold: created.rewardThreshold,
          programType: created.programType,
          isCompleted: true,
        ),
      );

      final updated = await container
          .read(businessSubscriptionActionsProvider)
          .grantBonusEntry(created.cardId);

      expect(updated?.currentStamps, created.currentStamps);
      expect(updated?.isCompleted, isTrue);
    });
  });

  group('BusinessSubscriptionActions.redeemDeliveryReward', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      await DriftBusinessRepository(db).saveBusinessProfile(
        BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: DateTime.now(),
        ),
      );
      await DriftCustomerRepository(db).saveCustomer(
        CustomerRecord(
          customerId: 'customer-1',
          businessId: 'business-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          displayName: 'Ana Client',
        ),
      );
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test('redeeming increments the customer reward count', () async {
      await container
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: 'business-1',
            customerId: 'customer-1',
            name: 'Delivery Pizza',
            rewardThreshold: 5,
            programType: LoyaltyProgramType.delivery,
          );
      final created = (await DriftCardRepository(
        db,
      ).listLoyaltyCards('business-1')).single;
      final repository = DriftCardRepository(db);
      await repository.saveLoyaltyCard(
        LoyaltyCard(
          businessId: created.businessId,
          cardId: created.cardId,
          customerId: created.customerId,
          name: created.name,
          createdAt: created.createdAt,
          status: created.status,
          currentStamps: 5,
          rewardThreshold: created.rewardThreshold,
          programType: created.programType,
          isBonusPending: false,
        ),
      );

      final updated = await container
          .read(businessSubscriptionActionsProvider)
          .redeemDeliveryReward(created.cardId);

      expect(updated?.isCompleted, isTrue);
      expect(
        (await DriftCustomerRepository(
          db,
        ).getCustomer('customer-1'))?.rewardsEarned,
        1,
      );
    });

    test(
      'adding a delivery stamp stamps the customer last-visit date',
      () async {
        await container
            .read(businessSubscriptionActionsProvider)
            .createLoyaltyCard(
              businessId: 'business-1',
              customerId: 'customer-1',
              name: 'Delivery Pizza',
              rewardThreshold: 5,
              programType: LoyaltyProgramType.delivery,
            );
        final created = (await DriftCardRepository(
          db,
        ).listLoyaltyCards('business-1')).single;

        await container
            .read(businessSubscriptionActionsProvider)
            .addDeliveryStamp(created.cardId);

        final customer = await DriftCustomerRepository(
          db,
        ).getCustomer('customer-1');
        expect(customer?.lastVisitAt, isNotNull);
      },
    );
  });
}
