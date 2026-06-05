import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/business_check_in_providers.dart';
import 'package:fidelio/app/providers/qr_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/repositories/drift_repositories.dart';
import 'package:fidelio/data/services/local_qr_service.dart';
import 'package:fidelio/domain/entities/business_profile.dart';
import 'package:fidelio/domain/entities/loyalty_card.dart';
import 'package:fidelio/domain/entities/subscription_card.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';
import 'package:fidelio/domain/value_objects/loyalty_program_type.dart';
import 'package:fidelio/domain/value_objects/subscription_type.dart';

void main() {
  group('BusinessCheckInController dynamic QR', () {
    final now = DateTime.utc(2026, 5, 13, 10);

    test('accepts a valid dynamic QR and decrements remaining uses', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => now),
        walletId: 'wallet-local',
        cardId: 'subscription-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      expect(result.isValid, isTrue);
      expect(result.message, 'Validated successfully');
      expect(result.subscription?.cardId, 'subscription-1');
      expect(
        (await DriftCardRepository(
          db,
        ).getSubscriptionCard('subscription-1'))?.remainingUses,
        4,
      );
      expect(
        (await DriftCardRepository(
          db,
        ).getSubscriptionCard('subscription-1'))?.linkedWalletId,
        'wallet-local',
      );
      final events = await DriftCheckInRepository(
        db,
      ).listCheckIns('business-1');
      expect(events, hasLength(1));
      expect(events.single.cardId, 'subscription-1');
      expect(events.single.result, 'valid');
    });

    test('rejects a subscription QR from a different wallet', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(
        db,
        now,
        linkedWalletId: 'wallet-owner',
      );

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => now),
        walletId: 'wallet-other',
        cardId: 'subscription-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      final subscription = await DriftCardRepository(
        db,
      ).getSubscriptionCard('subscription-1');
      expect(result.isValid, isFalse);
      expect(result.message, 'wallet mismatch');
      expect(subscription?.remainingUses, 5);
      expect(subscription?.linkedWalletId, 'wallet-owner');
      final events = await DriftCheckInRepository(
        db,
      ).listCheckIns('business-1');
      expect(events.single.result, 'wallet mismatch');
    });

    test('rejects an expired dynamic QR without decrementing uses', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(
          clock: () => now.subtract(const Duration(minutes: 3)),
        ),
        walletId: 'wallet-local',
        cardId: 'subscription-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      expect(result.isValid, isFalse);
      expect(result.message, 'invalid QR');
      expect(
        (await DriftCardRepository(
          db,
        ).getSubscriptionCard('subscription-1'))?.remainingUses,
        5,
      );
      final events = await DriftCheckInRepository(
        db,
      ).listCheckIns('business-1');
      expect(events, hasLength(1));
      expect(events.single.result, 'invalid QR');
    });

    test('rejects a replayed dynamic QR without decrementing twice', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => now),
        walletId: 'wallet-local',
        cardId: 'subscription-1',
      );
      final controller = container.read(businessCheckInControllerProvider);

      final firstResult = await controller.processRawPayload(rawPayload);
      final secondResult = await controller.processRawPayload(rawPayload);

      expect(firstResult.isValid, isTrue);
      expect(secondResult.isValid, isFalse);
      expect(secondResult.message, 'reused QR');
      expect(
        (await DriftCardRepository(
          db,
        ).getSubscriptionCard('subscription-1'))?.remainingUses,
        4,
      );
      final events = await DriftCheckInRepository(
        db,
      ).listCheckIns('business-1');
      expect(events, hasLength(2));
      expect(
        events.map((event) => event.result),
        containsAll(['valid', 'reused QR']),
      );
    });

    test(
      'rejects exhausted subscriptions without decrementing below zero',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            qrServiceProvider.overrideWithValue(
              LocalQrService(clock: () => now),
            ),
          ],
        );
        addTearDown(container.dispose);
        await _seedBusinessAndSubscription(db, now, remainingUses: 0);

        final rawPayload = await _dynamicRawPayload(
          service: LocalQrService(clock: () => now),
          walletId: 'wallet-local',
          cardId: 'subscription-1',
        );

        final result = await container
            .read(businessCheckInControllerProvider)
            .processRawPayload(rawPayload);

        expect(result.isValid, isFalse);
        expect(result.message, 'no entries');
        expect(
          (await DriftCardRepository(
            db,
          ).getSubscriptionCard('subscription-1'))?.remainingUses,
          0,
        );
        final events = await DriftCheckInRepository(
          db,
        ).listCheckIns('business-1');
        expect(events.single.result, 'no entries');
      },
    );

    test('rejects legacy static check-in payloads', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);

      final rawPayload = jsonEncode({
        'type': 'check_in_request',
        'version': 1,
        'businessId': 'business-1',
        'subscriptionId': 'subscription-1',
        'walletCardId': 'wallet-card-1',
        'timestamp': now.toIso8601String(),
        'nonce': null,
        'signature': null,
      });

      expect(
        () => container
            .read(businessCheckInControllerProvider)
            .processRawPayload(rawPayload),
        throwsFormatException,
      );
    });

    test('accepts a valid loyalty dynamic QR and adds a stamp', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);
      await DriftCardRepository(db).saveLoyaltyCard(
        LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee Loyalty',
          createdAt: now,
          status: CardStatus.active,
          currentStamps: 2,
          rewardThreshold: 8,
        ),
      );

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => now),
        walletId: 'wallet-local',
        cardId: 'loyalty-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      expect(result.isValid, isTrue);
      expect(
        (await DriftCardRepository(
          db,
        ).getLoyaltyCard('loyalty-1'))?.currentStamps,
        3,
      );
      expect(
        (await DriftCardRepository(
          db,
        ).getLoyaltyCard('loyalty-1'))?.linkedWalletId,
        'wallet-local',
      );
    });

    test('rejects a loyalty QR from a different wallet', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);
      await DriftCardRepository(db).saveLoyaltyCard(
        LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee Loyalty',
          createdAt: now,
          status: CardStatus.active,
          currentStamps: 2,
          rewardThreshold: 8,
          linkedWalletId: 'wallet-owner',
        ),
      );

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => now),
        walletId: 'wallet-other',
        cardId: 'loyalty-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      final loyalty = await DriftCardRepository(db).getLoyaltyCard('loyalty-1');
      expect(result.isValid, isFalse);
      expect(result.message, 'wallet mismatch');
      expect(loyalty?.currentStamps, 2);
      expect(loyalty?.linkedWalletId, 'wallet-owner');
      final events = await DriftCheckInRepository(
        db,
      ).listCheckIns('business-1');
      expect(events.single.result, 'wallet mismatch');
    });

    test(
      'rejects a replayed loyalty QR without adding a second stamp',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            qrServiceProvider.overrideWithValue(
              LocalQrService(clock: () => now),
            ),
          ],
        );
        addTearDown(container.dispose);
        await _seedBusinessAndSubscription(db, now);
        await DriftCardRepository(db).saveLoyaltyCard(
          LoyaltyCard(
            businessId: 'business-1',
            cardId: 'loyalty-1',
            customerId: 'customer-1',
            name: 'Coffee Loyalty',
            createdAt: now,
            status: CardStatus.active,
            currentStamps: 2,
            rewardThreshold: 8,
          ),
        );

        final rawPayload = await _dynamicRawPayload(
          service: LocalQrService(clock: () => now),
          walletId: 'wallet-local',
          cardId: 'loyalty-1',
        );
        final controller = container.read(businessCheckInControllerProvider);

        final firstResult = await controller.processRawPayload(rawPayload);
        final secondResult = await controller.processRawPayload(rawPayload);

        expect(firstResult.isValid, isTrue);
        expect(secondResult.isValid, isFalse);
        expect(secondResult.message, 'reused QR');
        expect(
          (await DriftCardRepository(
            db,
          ).getLoyaltyCard('loyalty-1'))?.currentStamps,
          3,
        );
      },
    );

    test('points loyalty card adds configured points per scan', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(LocalQrService(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);
      await DriftCardRepository(db).saveLoyaltyCard(
        LoyaltyCard(
          businessId: 'business-1',
          cardId: 'points-1',
          customerId: 'customer-1',
          name: 'Points club',
          createdAt: now,
          status: CardStatus.active,
          currentStamps: 20,
          rewardThreshold: 100,
          programType: LoyaltyProgramType.points,
          pointsPerScan: 15,
        ),
      );

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => now),
        walletId: 'wallet-local',
        cardId: 'points-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      final updated = await DriftCardRepository(db).getLoyaltyCard('points-1');
      expect(result.isValid, isTrue);
      expect(updated?.currentStamps, 35);
      expect(updated?.pointsPerScan, 15);
    });

    test('visit challenge resets progress after configured window', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final scanTime = now.add(const Duration(days: 10));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          qrServiceProvider.overrideWithValue(
            LocalQrService(clock: () => scanTime),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _seedBusinessAndSubscription(db, now);
      await DriftCardRepository(db).saveLoyaltyCard(
        LoyaltyCard(
          businessId: 'business-1',
          cardId: 'challenge-1',
          customerId: 'customer-1',
          name: '10 visits in 7 zile',
          createdAt: now,
          status: CardStatus.active,
          currentStamps: 6,
          rewardThreshold: 10,
          programType: LoyaltyProgramType.visitChallenge,
          challengeWindowDays: 7,
          challengeStartedAt: now,
        ),
      );

      final rawPayload = await _dynamicRawPayload(
        service: LocalQrService(clock: () => scanTime),
        walletId: 'wallet-local',
        cardId: 'challenge-1',
      );

      final result = await container
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);

      final updated = await DriftCardRepository(
        db,
      ).getLoyaltyCard('challenge-1');
      expect(result.isValid, isTrue);
      expect(updated?.currentStamps, 1);
      expect(updated?.challengeStartedAt, scanTime);
    });
  });
}

Future<void> _seedBusinessAndSubscription(
  AppDatabase db,
  DateTime now, {
  int remainingUses = 5,
  String? linkedWalletId,
}) async {
  await DriftBusinessRepository(db).saveBusinessProfile(
    BusinessProfile(
      businessId: 'business-1',
      displayName: 'Coffee Shop',
      createdAt: now,
    ),
  );
  await DriftCardRepository(db).saveSubscriptionCard(
    SubscriptionCard(
      businessId: 'business-1',
      cardId: 'subscription-1',
      customerId: 'customer-1',
      name: '5 entries',
      createdAt: now,
      status: CardStatus.active,
      subscriptionType: SubscriptionType.entries,
      startsAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      remainingUses: remainingUses,
      linkedWalletId: linkedWalletId,
    ),
  );
}

Future<String> _dynamicRawPayload({
  required LocalQrService service,
  required String walletId,
  required String cardId,
}) async {
  final payload = await service.createDynamicChallenge(
    walletId: walletId,
    cardId: cardId,
  );
  return service.encodeDynamicChallenge(payload);
}
