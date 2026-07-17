import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/data/services/local_qr_service.dart';
import 'package:fidelio/domain/entities/business_profile.dart';
import 'package:fidelio/domain/entities/loyalty_card.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';
import 'package:fidelio/domain/value_objects/qr_challenge_payload.dart';

void main() {
  group('LocalQrService dynamic challenge', () {
    final issuedAt = DateTime.utc(2026, 5, 13, 10);

    test('creates a payload that verifies successfully', () async {
      final service = LocalQrService(clock: () => issuedAt);

      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      expect(payload.type, LocalQrService.dynamicChallengeType);
      expect(payload.version, LocalQrService.dynamicChallengeVersion);
      expect(payload.walletId, 'wallet-1');
      expect(payload.cardId, 'card-1');
      expect(payload.dynamicChallenge, isNotEmpty);
      expect(payload.signature, isNotEmpty);
      expect(payload.timestamp, issuedAt);
      expect(await service.verifyDynamicChallenge(payload), isTrue);
    });

    test('rejects an expired payload', () async {
      final issuer = LocalQrService(clock: () => issuedAt);
      final verifier = LocalQrService(
        clock: () => issuedAt.add(const Duration(minutes: 3)),
      );

      final payload = await issuer.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      expect(await verifier.verifyDynamicChallenge(payload), isFalse);
    });

    test('rejects a tampered payload', () async {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      final tamperedPayload = QrChallengePayload(
        type: payload.type,
        version: payload.version,
        walletId: payload.walletId,
        cardId: 'card-2',
        dynamicChallenge: payload.dynamicChallenge,
        timestamp: payload.timestamp,
        signature: payload.signature,
      );

      expect(await service.verifyDynamicChallenge(tamperedPayload), isFalse);
    });

    test('rejects a payload with missing required fields', () async {
      final service = LocalQrService(clock: () => issuedAt);

      final payload = QrChallengePayload(
        type: LocalQrService.dynamicChallengeType,
        version: LocalQrService.dynamicChallengeVersion,
        walletId: '',
        cardId: 'card-1',
        dynamicChallenge: 'challenge',
        timestamp: issuedAt,
        signature: 'signature',
      );

      expect(await service.verifyDynamicChallenge(payload), isFalse);
    });

    test('rejects a payload issued too far in the future', () async {
      final issuer = LocalQrService(
        clock: () => issuedAt.add(const Duration(minutes: 1)),
      );
      final verifier = LocalQrService(clock: () => issuedAt);

      final payload = await issuer.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      expect(await verifier.verifyDynamicChallenge(payload), isFalse);
    });

    test('encodes and decodes a payload that still verifies', () async {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      final encoded = service.encodeDynamicChallenge(payload);
      final decoded = service.decodeDynamicChallenge(encoded);

      expect(decoded.type, payload.type);
      expect(decoded.version, payload.version);
      expect(decoded.walletId, payload.walletId);
      expect(decoded.cardId, payload.cardId);
      expect(decoded.dynamicChallenge, payload.dynamicChallenge);
      expect(decoded.timestamp, payload.timestamp);
      expect(decoded.signature, payload.signature);
      expect(await service.verifyDynamicChallenge(decoded), isTrue);
    });

    test('rejects encoded payloads with an invalid type', () async {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );
      final json = payload.toJson()..['type'] = 'other_qr';

      expect(
        () => service.decodeDynamicChallenge(
          service.encodeDynamicChallenge(QrChallengePayload.fromJson(json)),
        ),
        throwsFormatException,
      );
    });

    test('rejects encoded payloads with an unsupported version', () async {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );
      final json = payload.toJson()..['version'] = 99;

      expect(
        () => service.decodeDynamicChallenge(
          service.encodeDynamicChallenge(QrChallengePayload.fromJson(json)),
        ),
        throwsFormatException,
      );
    });

    test('creates a loyalty import payload with loyalty card type', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          activityDomain: 'Coffee',
          activitySymbol: 'coffee',
          cardAccentColor: 0xFF2563EB,
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee Loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 0,
          rewardThreshold: 8,
        ),
      );

      final decoded = service.decodeSubscriptionImportPayload(
        service.encodeSubscriptionImportPayload(payload),
      );

      expect(decoded.cardType, 'loyalty');
      expect(decoded.subscriptionId, 'loyalty-1');
      expect(decoded.cardTitle, 'Coffee Loyalty');
      expect(decoded.businessDomain, 'Coffee');
      expect(decoded.businessSymbol, 'coffee');
      expect(decoded.businessAccentColor, 0xFF2563EB);
      expect(decoded.entriesTotal, 8);
      expect(decoded.entriesRemaining, 8);
      expect(decoded.scanValue, 1);
      expect(decoded.signature, isNotEmpty);
    });

    test('rejects loyalty import payloads with a missing signature', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 0,
          rewardThreshold: 8,
        ),
      );
      final json = payload.toJson()..remove('signature');

      expect(
        () => service.decodeSubscriptionImportPayload(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('rejects tampered loyalty import payloads', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 0,
          rewardThreshold: 8,
        ),
      );
      final json = payload.toJson()..['cardTitle'] = 'Tampered card';

      expect(
        () => service.decodeSubscriptionImportPayload(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('rejects loyalty import payload with empty subscriptionId', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 0,
          rewardThreshold: 8,
        ),
      );
      final json = payload.toJson()..['subscriptionId'] = '';

      expect(
        () => service.decodeSubscriptionImportPayload(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('rejects loyalty import payload with empty businessId', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 0,
          rewardThreshold: 8,
        ),
      );
      final json = payload.toJson()..['businessId'] = '';

      expect(
        () => service.decodeSubscriptionImportPayload(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('rejects import payload with invalid cardType', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 0,
          rewardThreshold: 8,
        ),
      );
      final json = payload.toJson()..['cardType'] = 'reward_points';

      expect(
        () => service.decodeSubscriptionImportPayload(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('stamps remaining is clamped to zero when stamps exceed threshold', () {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = service.createLoyaltyImportPayload(
        business: BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: issuedAt,
        ),
        loyaltyCard: LoyaltyCard(
          businessId: 'business-1',
          cardId: 'loyalty-1',
          customerId: 'customer-1',
          name: 'Coffee loyalty',
          createdAt: issuedAt,
          status: CardStatus.active,
          currentStamps: 12,
          rewardThreshold: 8,
        ),
      );

      expect(payload.entriesRemaining, 0);
      expect(payload.entriesTotal, 8);
    });
  });

  group('LocalQrService dynamic challenge — edge cases', () {
    final issuedAt = DateTime.utc(2026, 5, 13, 10);

    test('throws ArgumentError for empty walletId', () async {
      final service = LocalQrService(clock: () => issuedAt);

      await expectLater(
        service.createDynamicChallenge(walletId: '', cardId: 'card-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for whitespace-only walletId', () async {
      final service = LocalQrService(clock: () => issuedAt);

      await expectLater(
        service.createDynamicChallenge(walletId: '   ', cardId: 'card-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for empty cardId', () async {
      final service = LocalQrService(clock: () => issuedAt);

      await expectLater(
        service.createDynamicChallenge(walletId: 'wallet-1', cardId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('consecutive challenges have different nonces', () async {
      final service = LocalQrService(clock: () => issuedAt);

      final p1 = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );
      final p2 = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      expect(p1.dynamicChallenge, isNot(equals(p2.dynamicChallenge)));
    });

    test('tampered nonce invalidates signature', () async {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      final tampered = QrChallengePayload(
        type: payload.type,
        version: payload.version,
        walletId: payload.walletId,
        cardId: payload.cardId,
        dynamicChallenge: 'AAAAAAAAAAAAAAAAAAAAAA==',
        timestamp: payload.timestamp,
        signature: payload.signature,
      );

      expect(await service.verifyDynamicChallenge(tampered), isFalse);
    });

    test('tampered walletId invalidates signature', () async {
      final service = LocalQrService(clock: () => issuedAt);
      final payload = await service.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      final tampered = QrChallengePayload(
        type: payload.type,
        version: payload.version,
        walletId: 'wallet-attacker',
        cardId: payload.cardId,
        dynamicChallenge: payload.dynamicChallenge,
        timestamp: payload.timestamp,
        signature: payload.signature,
      );

      expect(await service.verifyDynamicChallenge(tampered), isFalse);
    });

    test('clock skew within tolerance is accepted', () async {
      final clientService = LocalQrService(
        clock: () => issuedAt.add(const Duration(seconds: 8)),
      );
      final businessService = LocalQrService(clock: () => issuedAt);

      final payload = await clientService.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      expect(await businessService.verifyDynamicChallenge(payload), isTrue);
    });

    test('clock skew beyond tolerance is rejected', () async {
      final clientService = LocalQrService(
        clock: () => issuedAt.add(const Duration(seconds: 15)),
      );
      final businessService = LocalQrService(clock: () => issuedAt);

      final payload = await clientService.createDynamicChallenge(
        walletId: 'wallet-1',
        cardId: 'card-1',
      );

      expect(await businessService.verifyDynamicChallenge(payload), isFalse);
    });
  });
}
